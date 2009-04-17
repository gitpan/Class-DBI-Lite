
package Class::DBI::Lite;

use strict;
use warnings 'all';
use base 'Ima::DBI';
use Carp qw( cluck confess );
use SQL::Abstract;
use SQL::Abstract::Limit;
use Class::DBI::Lite::Iterator;
use Class::DBI::Lite::RootMeta;
use Class::DBI::Lite::EntityMeta;
use overload 
  '""'      => sub { eval { $_[0]->id } },
  bool      => sub { eval { $_[0]->id } },
  fallback  => 1;

our $VERSION = '0.025';
our $meta;

our %DBI_OPTIONS = (
  FetchHashKeyName    => 'NAME_lc',
  ShowErrorStatement  => 1,
  ChopBlanks          => 1,
  AutoCommit          => 1,
  RaiseError          => 1,
  RootClass           => 'DBIx::ContextualFetch',
);

BEGIN {
  use vars qw( $Weaken_Is_Available %Live_Objects $Connection );

  $Weaken_Is_Available = 1;
  eval {
	  require Scalar::Util;
	  import Scalar::Util qw(weaken isweak);
  };
  $Weaken_Is_Available = 0 if $@;
}# end BEGIN:


#==============================================================================
# Abstract methods:
sub set_up_table;
sub get_last_insert_id;


#==============================================================================
sub import
{
  my $class = shift;
  
  no strict 'refs';
  $class->_load_class( ( @{$class.'::ISA'} )[0] );
  if( my $table = eval { ( @{$class.'::ISA'} )[0]->table } )
  {
    $class->set_up_table( $table );
  }# end if()
}# end import()


#==============================================================================
sub clear_object_index
{
  my $s = shift;
  
  my $class = ref($s) ? ref($s) : $s;
  my $key_starter = $s->root_meta->{schema} . ":" . $class;
  map { delete($Live_Objects{$_}) } grep { m/^$key_starter\:\d+/o } keys(%Live_Objects);
}# end clear_object_index()


#==============================================================================
sub find_column
{
  my ($class, $name) = @_;
  
  my ($col) = grep { $_ eq $name } $class->columns('All')
    or return;
  return $col;
}# end find_column()


#==============================================================================
sub construct
{
  my ($s, $data) = @_;
  
  my $class = ref($s) ? ref($s) : $s;
  
  my $PK = $class->primary_column;
  my $key = join ':', grep { defined($_) } ( $s->root_meta->{schema}, $class, $data->{ $PK } );
  return $Live_Objects{$key} if $Live_Objects{$key};
  
  $data->{__id} = $data->{ $PK };
  $data->{__Changed} = { };
  
  my $obj = bless $data, $class;
  if( $Weaken_Is_Available )
  {
    $Live_Objects{$key} = $obj;
    
    weaken( $Live_Objects{$key} );
    return $Live_Objects{$key};
  }
  else
  {
    return $obj;
  }# end if()
}# end construct()


#==============================================================================
sub deconstruct
{
  my $s = shift;
  
  bless $s, 'Class::DBI::Lite::Object::Has::Been::Deleted';
}# end deconstruct()


#==============================================================================
sub schema { $_[0]->root_meta->{schema} }
sub dsn    { $_[0]->root_meta->{dsn} }
sub table  { $_[0]->_meta->{table} }
sub triggers { @{ $_[0]->_meta->{triggers}->{ $_[1] } } }
sub _meta { }


#==============================================================================
sub _init_meta
{
  my ($class, $entity) = @_;
  
  no strict 'refs';
  no warnings qw( once redefine );
  my $schema = $class->connection->[0];
  
  my $_class_meta = Class::DBI::Lite::EntityMeta->new( $class, $schema, $entity );
  *{"$class\::_meta"} = sub { $_class_meta };
  
  my $pk = ($class->columns('Primary'))[0];
  *{"$class\::primary_column"} = sub { $pk };
}# end _init_meta()


#==============================================================================
sub connection
{
  my ($class, @DSN) = @_;
  
  if( $Connection && ! @DSN )
  {
    return $Connection;
  }# end if()
  
  # Set up the root meta:
  no strict 'refs';
  no warnings 'redefine';
  my $meta = Class::DBI::Lite::RootMeta->new(
    \@DSN
  );
  *{ $class->root . "::root_meta" } = sub { $meta };
  
  # Connect:
  undef(%Live_Objects);
  local $^W = 0;
  $class->set_db('Main' => @DSN, {
		RaiseError => 1,
		AutoCommit => 1,
		PrintError => 0,
		Taint      => 1,
		RootClass  => "DBIx::ContextualFetch"
  });
  $Connection = \@DSN;
}# end connection()


#==============================================================================
sub root
{
  __PACKAGE__;
}# end root()


#==============================================================================
sub root_meta
{
  my $s = shift;
  
  no strict 'refs';
  my $root = $s->root;

  ${"$root\::root_meta"};
}# end root_meta()


#==============================================================================
sub id
{
  $_[0]->{ $_[0]->primary_column };
}# end id()


#==============================================================================
my %ok_types = (
  All       => 1,
  Essential => 1,
  Primary   => 1,
);
sub columns
{
  my ($s) = shift;
  
  
  if( my $type = shift(@_) )
  {
    confess "Unknown column group '$type'" unless $ok_types{$type};
    if( my @cols = @_ )
    {
      $s->_meta->columns->{$type} = \@cols;
    }
    else
    {
      # Get: my ($PK) = $class->columns('Primary');
      return @{ $s->_meta->columns->{$type} };
    }# end if()
  }
  else
  {
    return @{ $s->_meta->columns->{All} };
  }# end if()

}# end columns()


#==============================================================================
sub retrieve_all
{
  my ($s) = @_;
  
  return $s->retrieve_from_sql(  );
}# end retrieve_all()


#==============================================================================
sub retrieve
{
  my ($s, $id) = @_;
  
  my ($obj) = $s->retrieve_from_sql(<<"", $id);
    @{[ $s->primary_column ]} = ?

  return $obj;
}# end retrieve()


#==============================================================================
sub create
{
  my $s = shift;
  
  my $data = ref($_[0]) ? $_[0] : { @_ };
  
  my $PK = $s->primary_column;
  my %create_fields = map { $_ => $data->{$_} }
                        grep { exists($data->{$_}) && $_ ne $PK }
                          $s->columns('All');
  
  my $pre_obj = bless {
    __id => undef,
    __Changed => { },
    %create_fields
  }, ref($s) ? ref($s) : $s;
  
  # Cal the "before" trigger:
  $pre_obj->_call_triggers( before_create => \%create_fields );
  
  # Changes may have happened to the original creation data (from the trigger(s)) - re-evaluate now:
  %create_fields =  map { $_ => $pre_obj->{$_} }
                      grep { defined($pre_obj->{$_}) && $_ ne $PK }
                        $pre_obj->columns('All');
  $data = { %$pre_obj  };
  
  my @fields  = map { $_ } sort grep { exists($data->{$_}) } keys(%create_fields);
  my @vals    = map { $data->{$_} } sort grep { exists($data->{$_}) } keys(%create_fields);
  
  my $sql = <<"";
    INSERT INTO @{[ $s->table ]} (
      @{[ join ',', @fields ]}
    )
    VALUES (
      @{[ join ',', map {"?"} @vals ]}
    )

  my $sth = $s->db_Main->prepare_cached( $sql );
  $sth->execute( map { $pre_obj->{$_} } @fields );
  my $id = $s->get_last_insert_id
    or confess "ERROR - CANNOT get last insert id";
  $sth->finish();
  $pre_obj->discard_changes();
  
  $pre_obj->{$PK} = $id;
  $pre_obj->_call_triggers( after_create => $pre_obj );
  $pre_obj;
}# end create()


#==============================================================================
sub do_transaction
{
  my ($s, $code) = @_;
  
  local $s->db_Main->{AutoCommit};
  my $res = eval { $code->( ) };
  
  if( my $trans_error = $@ )
  {
    eval { $s->dbi_rollback };
    if( my $rollback_error = $@ )
    {
      confess join "\n\t",  "Both transaction and rollback failed:",
                            "Transaction error: $trans_error",
                            "Rollback Error: $rollback_error";
    }
    else
    {
      confess join "\n\t",  "Transaction failed but rollback succeeded:",
                            "Transaction error: $trans_error";
    }# end if()
  }
  else
  {
    # Success:
    $s->commit;
    return $res;
  }# end if()
}# end do_transaction()


#==============================================================================
sub update
{
  my $s = shift;
  confess "$s\->update cannot be called without an object" unless ref($s);
  
  return 1 unless eval { keys(%{ $s->{__Changed} }) };
  
  $s->_call_triggers( before_update => $s );
  
  my $changed = delete( $s->{__Changed} );
  $s->{__Changed} = { };
  my @fields  = map { "$_ = ?" } grep { $changed->{$_} } sort keys(%$s);
  my @vals    = map { $s->{$_} } grep { $changed->{$_} } sort keys(%$s);
  
  foreach my $field ( grep { $changed->{$_} } sort keys(%$s) )
  {
    $s->_call_triggers( "before_update_$field", $changed->{$field}->{oldval}, $s->{$field} );
  }# end foreach()
  
  # Make our SQL:
  my $sql = <<"";
    UPDATE @{[ $s->table ]} SET
      @{[ join ', ', @fields ]}
    WHERE @{[ $s->primary_column ]} = ?

  my $sth = $s->db_Main->prepare_cached( $sql );
  $sth->execute( @vals, $s->id );
  $sth->finish();
  
  foreach my $field ( grep { $changed->{$_} } sort keys(%$s) )
  {
    my $old_val = $changed->{$field}->{oldval};
    $s->_call_triggers( "after_update_$field", $old_val, $s->{$field} );
  }# end foreach()
  
  $s->{__Changed} = undef;
  $s->_call_triggers( after_update => $s );
  return 1;
}# end update()


#==============================================================================
sub delete
{
  my $s = shift;
  
  confess "$s\->delete cannot be called without an object" unless ref($s);
  
  $s->_call_triggers( before_delete => $s );
  
  my $sql = <<"";
    DELETE FROM @{[ $s->table ]}
    WHERE @{[ $s->primary_column ]} = ?

  my $sth = $s->db_Main->prepare_cached( $sql );
  $sth->execute( $s->id );
  $sth->finish();
  
  my $deleted = bless { $s->primary_column => $s->id }, ref($s);
  my $key = join ':', grep { defined($_) } ($s->root_meta->{schema}, ref($s), $s->id );
  $s->_call_triggers( after_delete => $deleted );
  delete($Live_Objects{$key});
  undef(%$deleted);
  
  undef(%$s);

  $s->deconstruct;
}# end delete()


#==============================================================================
sub ad_hoc
{
  my ($s, %args) = @_;
  
  my $sth = $s->db_Main->prepare( $args{sql} );
  $args{args} ||= [ ];
  $args{isa}  ||= 'Class::DBI::Lite';
  $sth->execute( @{ $args{args} } );
  my @data = ( );
  require Class::DBI::Lite::AdHocEntity;
  while( my $rec = $sth->fetchrow_hashref )
  {
    push @data, Class::DBI::Lite::AdHocEntity->new(
      isa         => $args{isa},
      sql         => \$args{sql},
      args        => $args{args},
      primary_key => $args{primary_key},
      data        => $rec,
    );
  }# end while()
  $sth->finish();
  
  return wantarray ? @data : Class::DBI::Lite::Iterator->new( \@data );
}# end ad_hoc()


#==============================================================================
sub retrieve_from_sql
{
  my ($s, $sql, @bind) = @_;
  
  $sql = "SELECT @{[ join ', ', $s->columns('Essential') ]} FROM @{[ $s->table ]}" . ( $sql ? " WHERE $sql " : "" );
  SCOPE: {
    my $sth = $s->db_Main->prepare_cached( $sql );
    $sth->execute( @bind );
    
    return $s->sth_to_objects( $sth, $sql );
  }
}# end retrieve_from_sql()


#==============================================================================
sub sth_to_objects
{
  my ($s, $sth, $sql) = @_;
  
  my $class = ref($s) ? ref($s) : $s;
  if( wantarray )
  {
    my @vals = map { $class->construct( $_ ) } $sth->fetchall_hash;
    $sth->finish();
    return @vals;
  }
  else
  {
    my $iter = Class::DBI::Lite::Iterator->new(
      [
        map { $class->construct( $_ ) } $sth->fetchall_hash
      ]
    );
    $sth->finish();
    return $iter;
  }# end if()
}# end sth_to_objects()


#==============================================================================
sub search
{
  my ($s, %args) = @_;
  
  my $sql = "";

  my @sql_parts = map { "$_ = ?" } sort keys(%args);
  my @sql_vals  = map { $args{$_} } sort keys(%args);
  $sql .= join ' AND ', @sql_parts;
  
  return $s->retrieve_from_sql( $sql, @sql_vals );
}# end search()


#==============================================================================
sub count_search
{
  my ($s, %args) = @_;
  
  my $sql = "SELECT COUNT(*) FROM @{[ $s->table ]} WHERE ";

  my @sql_parts = map { "$_ = ?" } sort keys(%args);
  my @sql_vals  = map { $args{$_} } sort keys(%args);
  $sql .= join ' AND ', @sql_parts;
  
  SCOPE: {
    my $sth = $s->db_Main->prepare_cached( $sql );
    $sth->execute( @sql_vals );
    my ($count) = $sth->fetchrow;
    $sth->finish();
    
    return $count;
  };
}# end count_search()


#==============================================================================
sub search_like
{
  my ($s, %args) = @_;
  
  my $sql = "";

  my @sql_parts = map { "$_ LIKE ?" } sort keys(%args);
  my @sql_vals  = map { $args{$_} } sort keys(%args);
  $sql .= join ' AND ', @sql_parts;
  
  return $s->retrieve_from_sql( $sql, @sql_vals );
}# end search_like()


#==============================================================================
sub count_search_like
{
  my ($s, %args) = @_;
  
  my $sql = "SELECT COUNT(*) FROM @{[ $s->table ]} WHERE ";

  my @sql_parts = map { "$_ LIKE ?" } sort keys(%args);
  my @sql_vals  = map { $args{$_} } sort keys(%args);
  $sql .= join ' AND ', @sql_parts;
  
  SCOPE: {
    my $sth = $s->db_Main->prepare_cached( $sql );
    $sth->execute( @sql_vals );
    my ($count) = $sth->fetchrow;
    $sth->finish();
    
    return $count;
  };
}# end count_search_like()


#==============================================================================
sub search_where
{
  my $s = shift;
  
  my $where = (ref $_[0]) ? $_[0]          : { @_ };
  my $attr  = (ref $_[0]) ? $_[1]          : undef;
  my $order = ($attr)     ? delete($attr->{order_by}) : undef;
  my $limit  = ($attr)    ? delete($attr->{limit})    : undef;
  my $offset = ($attr)    ? delete($attr->{offset})   : undef;
  
  my $sql = SQL::Abstract::Limit->new(%$attr, limit_dialect => $s->db_Main );
  my($phrase, @bind) = $sql->where($where, $order, $limit, $offset);
  $phrase =~ s/^\s*WHERE\s*//i;
  
  return $s->retrieve_from_sql($phrase, @bind);
}# end search_where()


#==============================================================================
sub count_search_where
{
  my $s = shift;
  
  my $where = (ref $_[0]) ? $_[0]          : { @_ };
  my $attr  = (ref $_[0]) ? $_[1]          : undef;
  my $order = ($attr)     ? delete($attr->{order_by}) : undef;
  my $limit  = ($attr)    ? delete($attr->{limit})    : undef;
  my $offset = ($attr)    ? delete($attr->{offset})   : undef;
  
  my $abstract = SQL::Abstract::Limit->new(%$attr, limit_dialect => $s->db_Main );
  my($phrase, @bind) = $abstract->where($where, $order, $limit, $offset);
  $phrase =~ s/^\s*WHERE\s*//i;
  
  my $sql = "SELECT COUNT(*) FROM @{[ $s->table ]} WHERE $phrase";
  
  SCOPE: {
    my $sth = $s->db_Main->prepare_cached($sql);
    $sth->execute( @bind );
    my ($count) = $sth->fetchrow;
    $sth->finish;
    
    return $count;
  };
}# end count_search_where()


#==============================================================================
sub has_a
{
  my ($class, $method, $otherClass, $fk) = @_;
  
  $class->_load_class( $otherClass );

  $class->_meta->{has_a_rels}->{$method} = {
    class => $otherClass,
    fk    => $fk
  };
  
  no strict 'refs';
  *{"$class\::$method"} = sub {
    my $s = shift;
    
    $otherClass->retrieve( $s->$fk );
  };
}# end has_a()


#==============================================================================
sub has_many
{
  my ($class, $method, $otherClass, $fk) = @_;
  
  $class->_load_class( $otherClass );
  $class->_meta->{has_many_rels}->{$method} = {
    class => $otherClass,
    fk    => $fk,
  };
  
  no strict 'refs';
  *{"$class\::$method"} = sub {
    my $s = shift;
    $otherClass->search( $fk => $s->$fk );
  };
  
  *{"$class\::add_to_$method"} = sub {
    my $s = shift;
    my %options = ref($_[0]) ? %{$_[0]} : @_;
    $otherClass->create(
      %options,
      $fk => $s->id,
    );
  };
  
  $class->add_trigger( after_delete => sub {
    my $s = shift;
    $_->delete foreach $s->$method;
  });
}# end has_many()


#==============================================================================
sub add_trigger
{
  my ($s, $event, $handler) = @_;
  
  confess "add_trigger called but the handler is not a subref"
    unless ref($handler) eq 'CODE';
  
  $s->_meta->{triggers}->{$event} ||= [ ];
  my $handlers = $s->_meta->{triggers}->{$event};
  return if grep { $_ eq $handler } @$handlers;

  push @$handlers, $handler;
}# end add_trigger()


#==============================================================================
sub _call_triggers
{
  my ($s, $event) = @_;
  
  $s->_meta->{triggers}->{ $event } ||= [ ];
  return unless my @handlers = @{ $s->_meta->{triggers}->{ $event } };
  shift;shift;
  foreach my $handler ( @handlers )
  {
    eval {
      $handler->( $s, @_ );
      1;
    } or confess $@;
  }# end foreach()
}# end _call_triggers()


#==============================================================================
sub dbi_commit
{
  my $s = shift;
  return if $s->db_Main->{AutoCommit};
  $s->SUPER::commit( @_ );
}# end dbi_commit()


#==============================================================================
sub remove_from_object_index
{
  my $s = shift;
  my $obj = delete($Live_Objects{$s->root_meta->{schema} . ':' . ref($s) . ':' . $s->id });
  undef(%$obj);
}# end remove_from_object_index()


#==============================================================================
sub dbi_rollback
{
  my $s = shift;
  $s->SUPER::rollback( @_ );
}# end dbi_rollback()


#==============================================================================
sub discard_changes
{
  my $s = shift;
  
  map {
    $s->{$_} = $s->{__Changed}->{$_}->{oldval}
  } keys(%{$s->{__Changed}});
  
  $s->{__Changed} = { };
  
  1;
}# end discard_changes()


#==============================================================================
sub _load_class
{
  my (undef, $class) = @_;
  
  (my $file = "$class.pm") =~ s/::/\//g;
  unless( $INC{$file} )
  {
    require $file;
    $class->import;
  }# end unless();
}# end _load_class()


#==============================================================================
sub _flesh_out
{
  my $s = shift;
  
  my @missing_fields = grep { ! exists($s->{$_}) } $s->columns('All');
  my $sth = $s->db_Main->prepare(<<"");
    SELECT @{[ join ', ', @missing_fields ]}
    FROM @{[ $s->table ]}
    WHERE @{[ $s->primary_column ]} = ?

  $sth->execute( $s->id );
  my $rec = $sth->fetchrow_hashref;
  $sth->finish();
  
  $s->{$_} = $rec->{$_} foreach @missing_fields;
  return 1;
}# end _flesh_out()


#==============================================================================
sub AUTOLOAD
{
  my $s = shift;
  our $AUTOLOAD;
  my ($name) = $AUTOLOAD =~ m/([^:]+)$/;

  if( my ($col) = grep { $_ eq $name } $s->columns('All') )
  {
    exists($s->{$col}) or $s->_flesh_out;
    if( @_ )
    {
      my $newval = shift;
      no warnings 'uninitialized';
      return $newval if $newval eq $s->{$name};
      $s->_call_triggers( "before_set_$name", $s->{$name}, $newval );
      $s->{__Changed}->{$name} = {
        oldval => $s->{$name}
      };
      return $s->{$name} = $newval;
    }
    else
    {
      return $s->{$name};
    }# end if()
  }
  else
  {
    my $class = ref($s) ? ref($s) : $s;
    confess "Unknown field or method '$name' for class $class";
  }# end if()
}# end AUTOLOAD()


#==============================================================================
sub DESTROY
{
  my $s = shift;
  
  if( $s->{__Changed} && keys(%{ $s->{__Changed} }) )
  {
    my $changed = join ', ', sort keys(%{ $s->{__Changed} });
    cluck ref($s) . " #$s->{__id} DESTROY'd without saving changes to $changed";
  }# end if()
  
  delete($s->{$_}) foreach keys(%$s);
}# end DESTROY()

{
  # This is deleted-object-heaven:
  package Class::DBI::Lite::Object::Has::Been::Deleted;

  use overload 
    '""'      => sub { '' },
    bool      => sub { undef },
    fallback  => 1;
}

1;# return true:

__END__

=pod

=head1 NAME

Class::DBI::Lite - Lightweight ORM for Perl

=head1 SYNOPSIS

Create some database tables:

  create table artists (
    artist_id integer primary key autoincrement,
    artist_name varchar(100) not null
  );
  
  create table cds (
    cd_id integer primary key autoincrement,
    artist_id integer not null,
    cd_name varchar(100) not null
  );


  package My::Model;
  
  use base 'Class::DBI::Lite::mysql'; # Or ::SQLite, etc
  
  __PACKAGE__->connection( 'DBI:mysql:dbname:localhost', 'user', 'pass' );
  
  1;# return true:


  package My::Artist;
  
  use base 'My::Model';
  
  __PACKAGE__->set_up_table('artists');
  
  __PACKAGE__->has_many(
    cds =>
      'My::CD' =>
        'artist_id'
  );
  
  1;# return true:


  package My::CD;
  
  use base 'My::Model';
  
  __PACKAGE__->set_up_table('cds');
  
  __PACKAGE__->has_a(
    artist =>
      'My::Artist' =>
        'artist_id'
  );
  
  1;# return true:

Then, in your script someplace:

  use My::Artist;
  
  my $artist = My::Artist->retrieve( 123 );
  
  foreach my $cd ( $artist->cds )
  {
    ...
  }# end foreach()
  
  my $cd = $artist->add_to_cds( cd_name => "Attak" );
  
  print $cd->cd_name;
  $cd->cd_name("New Name");
  $cd->update();
  
  # Delete the artist and all of its CDs:
  $artist->delete;

=head1 DESCRIPTION

Sometimes Class::DBI is too crufty, and DBIx::Class is too much.

Enter Class::DBI::Lite.

=head1 TODO

=over 4

=item * Complete tests

=item * Examples

=item * Documentation

=back

=head1 AUTHOR

Copyright John Drago <jdrago_999@yahoo.com>.  All rights reserved.

=head1 LICENSE

This software is Free software and may be used and redistributed under the
same terms as perl itself.

=cut

