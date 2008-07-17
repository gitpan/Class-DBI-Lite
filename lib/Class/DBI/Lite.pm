
package Class::DBI::Lite;

our $VERSION = '0.002_01';

use strict;
use warnings 'all';
use base qw( Class::Data::Inheritable );
use DBI;
use Carp qw( confess cluck );
use Class::DBI::Lite::Iterator;
use SQL::Abstract;
use SQL::Abstract::Limit;

use overload 
  '""' => sub { eval { $_[0]->id } },
  bool => sub { eval { $_[0]->id } },
  fallback => 1;

use vars qw($Weaken_Is_Available);

BEGIN {
	$Weaken_Is_Available = 1;
	eval {
		require Scalar::Util;
		import Scalar::Util qw(weaken);
	};
	if ($@) {
		$Weaken_Is_Available = 0;
	}
}

our %DBI_OPTIONS = (
  FetchHashKeyName    => 'NAME_lc',
  ShowErrorStatement  => 1,
  ChopBlanks          => 1,
  AutoCommit          => 1,
  RaiseError          => 1,
  RootClass           => 'DBIx::ContextualFetch',
);

my %Live_Objects = ( );

#==============================================================================
BEGIN
{
__PACKAGE__->mk_classdata('_table');
__PACKAGE__->mk_classdata('_handles' => { });
__PACKAGE__->mk_classdata('_dbh');
__PACKAGE__->mk_classdata('_columns' => { });
__PACKAGE__->mk_classdata('_dsn');
__PACKAGE__->mk_classdata('_schema');
__PACKAGE__->mk_classdata('_driver');
__PACKAGE__->mk_classdata('_has_a_rels' => { });
__PACKAGE__->mk_classdata('_has_many_rels' => { });
__PACKAGE__->mk_classdata('_triggers' => { });
}


#==============================================================================
sub connection
{
  my ($class, @dsn) = @_;
  
  confess "Usage: $class\->connection( \@dsn )"
    unless @dsn;
  my $key = join ':', @dsn[0...2];
  $class->_dsn( $dsn[0] );
  my (undef, undef, $schema) = split /:/, $class->_dsn;
  $class->_schema( $schema );
  if( my $h = $class->_handles->{$key} )
  {
    $class->_dbh( $h->{dbh} );
  }
  else
  {
    my $new = DBI->connect( @dsn, \%DBI_OPTIONS );
    $class->_handles->{$key} = {
      dbh => $new,
    };
    $class->_dbh( $class->_handles->{$key}->{dbh} );
  }# end if()
  undef(%Live_Objects);
}# end connection()


#==============================================================================
sub db_Main
{
  my $class = shift;
  $class->_dbh;
}# end db_Main()


#==============================================================================
sub columns
{
  my $s = shift;
  
  if( @_ )
  {
    my $group = "_columns_" . lc(shift);
    if( @_ )
    {
      $s->$group( @_ );
    }
    else
    {
      $s->$group;
    }# end if()
  }
  else
  {
    $s->_columns_all;
  }# end if()
}# end columns()


#==============================================================================
sub _columns_all
{
  my $s = shift;
  
  if( @_ )
  {
    $s->_columns->{$s->table}->{all} = [ @_ ];
  }
  else
  {
    @{ $s->_columns->{$s->table}->{all} };
  }# end if()
}# end _columns_all()


#==============================================================================
sub _columns_primary
{
  my $s = shift;
  
  if( @_ )
  {
    $s->_columns->{$s->table}->{primary} = [ @_ ];
  }
  else
  {
    $s->_columns->{$s->table}->{primary}->[0];
  }# end if()
}# end _columns_primary()


#==============================================================================
sub set_up_table
{
  my $class = shift;
  $class->_table( shift );
  
  # Now load our driver:
  my (undef, $driver) = split /:/, $class->_dsn;
  my $driver_class = "Class::DBI::Lite::Driver::$driver";
  my $driver_file = "Class/DBI/Lite/Driver/$driver.pm";
  eval {
    no strict 'refs';
    require $driver_file unless @{"$driver_class\::ISA"};
    1;
  } or confess "Cannot load driver class '$driver_class': $@";
  
  # Have the driver take care of any additional setup:
  $class->_driver(
    $driver_class->new(
      root => $class,
    )
  )->set_up_table( $class->table );
}# end set_up_table()


#==============================================================================
sub table
{
  my $class = shift;
  
  @_ ? $class->set_up_table( @_ ) : $class->_table;
}# end table()


#==============================================================================
sub construct
{
  my ($s, $data) = @_;
  
  my $class = ref($s) ? ref($s) : $s;
  
  my $PK = $class->primary_column;
  my $key = join ':', $class, $data->{ $PK };
  return $Live_Objects{$key} if $Live_Objects{$key};
  
  my $obj = bless {
    %$data,
    __id => $data->{ $PK },
    __Changed => { },
  }, $class;
  weaken( $Live_Objects{$key} = $obj )
    if $Weaken_Is_Available;
  return $obj;
}# end construct()


#==============================================================================
sub retrieve
{
  my ($s, $id) = @_;
  
  my ($obj) = $s->retrieve_from_sql(<<"", $id);
    @{[ $s->_columns_primary ]} = ?

  return $obj;
}# end retrieve()


#==============================================================================
sub retrieve_all
{
  my ($s) = @_;
  
  return $s->retrieve_from_sql( "" );
}# end retrieve_all()


#==============================================================================
sub id
{
  my $s = shift;
  
  $s->{__id};
}# end id()


#==============================================================================
sub primary_column
{
  my $class = shift;
  $class->_columns_primary;
}# end primary_column()


#==============================================================================
sub retrieve_from_sql
{
  my ($s, $sql, @bind) = @_;
  
  $sql = "SELECT * FROM @{[ $s->table ]}" . ( $sql ? " WHERE $sql " : "" );

  my $sth = $s->_dbh->prepare_cached( $sql );
  $sth->execute( @bind );
  
  return $s->sth_to_objects( $sth );
}# end retrieve_from_sql()


#==============================================================================
sub sth_to_objects
{
  my ($s, $sth) = @_;
  
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
sub create
{
  my $s = shift;
  my $data = ref($_[0]) ? $_[0] : { @_ };
  
  my $PK = $s->_columns_primary;
  my %create_fields = map { $_ => $data->{$_} } grep { $_ ne $PK } $s->_columns_all;
  
  $s->_call_triggers( before_create => \%create_fields );
  
  my @fields  = map { $_ } sort grep { exists($data->{$_}) } keys(%create_fields);
  my @vals    = map { $data->{$_} } sort grep { exists($data->{$_}) } keys(%create_fields);
  
  my $sql = <<"";
    INSERT INTO @{[ $s->table ]} (
      @{[ join ',', @fields ]}
    )
    VALUES (
      @{[ join ',', map {"?"} @vals ]}
    )

  my $sth = $s->_dbh->prepare_cached( $sql );
  $sth->execute( @vals );
  my $id = $s->_driver->get_last_insert_id;
  $sth->finish();
  
  my $obj = $s->retrieve( $id );
  $s->_call_triggers( after_create => $obj );
  return $obj;
}# end create()


#==============================================================================
sub update
{
  my $s = shift;
  confess "$s\->update cannot be called without an object" unless ref($s);
  
  return unless $s->{__Changed} && keys(%{ $s->{__Changed} });
  
  $s->_call_triggers( before_update => $s );
  
  my @fields  = map { "$_ = ?" } grep { $s->{__Changed}->{$_} } sort keys(%$s);
  my @vals    = map { $s->{$_} } grep { $s->{__Changed}->{$_} } sort keys(%$s);
  
  # Make our SQL:
  my $sql = <<"";
    UPDATE @{[ $s->table ]} SET
      @{[ join ', ', @fields ]}
    WHERE @{[ $s->_columns_primary ]} = ?

  my $sth = $s->_dbh->prepare_cached( $sql );
  $sth->execute( @vals, $s->id );
  $sth->finish();
  
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
    WHERE @{[ $s->_columns_primary ]} = ?

  my $sth = $s->_dbh->prepare_cached( $sql );
  $sth->execute( $s->id );
  $sth->finish();
  
  my $deleted = bless { $s->primary_column => $s->id }, ref($s);
  my $key = ref($s) . ':' . $s->id;
  $s->_call_triggers( after_delete => $deleted );
  delete($Live_Objects{$key});
  undef(%$deleted);
  
  undef(%$s);
  bless $s, 'Class::DBI::Lite::Object::Has::Been::Deleted';
  return 1;
}# end delete()


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
  
  my $sth = $s->_dbh->prepare_cached( $sql );
  $sth->execute( @sql_vals );
  my ($count) = $sth->fetchrow;
  $sth->finish();
  
  return $count;
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
  
  my $sth = $s->_dbh->prepare_cached( $sql );
  $sth->execute( @sql_vals );
  my ($count) = $sth->fetchrow;
  $sth->finish();
  
  return $count;
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
  
  my $sql = SQL::Abstract::Limit->new(%$attr);
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
  
  my $abstract = SQL::Abstract::Limit->new(%$attr);
  my($phrase, @bind) = $abstract->where($where, $order, $limit, $offset);
  $phrase =~ s/^\s*WHERE\s*//i;
  
  my $sql = "SELECT COUNT(*) FROM @{[ $s->table ]} WHERE $phrase";
  my $sth = $s->_dbh->prepare_cached($sql);
  $sth->execute( @bind );
  my ($count) = $sth->fetchrow;
  $sth->finish;
  
  return $count;
}# end count_search_where()


#==============================================================================
#  ->has_many(
#    things => 'My::Thing' => 'thing_id' 
#  )
sub has_many
{
  my $class = shift;
  $class->_add_relationship( 'has_many', @_ );
}# end has_many()


#==============================================================================
#  ->has_a(
#    thing => 'My::Thing' => 'thing_id'
#  )
sub has_a
{
  my $class = shift;
  $class->_add_relationship( 'has_a', @_ );
}# end has_a()


#==============================================================================
sub _add_relationship
{
  my ($class, $type, $method, $otherclass, $FK) = @_;
  
  # Make sure the other class is loaded/loadable:
  {
    no strict 'refs';
    (my $otherpkg = "$otherclass.pm") =~ s/::/\//g;
    eval { require $otherpkg unless @{"$otherclass\::ISA"}; 1; }
      or confess "Cannot load package '$otherclass': $@";
  }
  
  $FK ||= $otherclass->_columns_primary;
  
  no strict 'refs';
  my $PK = $class->primary_column;
  *{"$class\::add_to_$method"} = sub {
    my $s = shift;
    my %data = ref($_[0]) ? %{ $_[0] } : @_;
    $otherclass->create(
      %data,
      $PK => $s->id,
    );
  };
  if( $type eq 'has_many' )
  {
    *{"$class\::$method"} = sub {
      my $s = shift;
      $otherclass->search( $FK => $s->id );
    };
    # Also add a trigger for after_delete:
    $class->add_trigger( after_delete => sub {
      my $s = shift;
      # XXX: Maybe change this to simply delete (via SQL) from $otherclass->table
      # where $FK = $s->id:
      $_->delete foreach $s->$method;
    });
  }
  elsif( $type eq 'has_a' )
  {
    *{"$class\::$method"} = sub {
      my $s = shift;
      $otherclass->retrieve( $s->$FK );
    };
  }# end if()
  
  return 1;
}# end _add_relationship()


#==============================================================================
sub add_trigger
{
  my ($class, $event, $handler) = @_;
  
  $class->_triggers->{ $class->table } ||= { };
  $class->_triggers->{ $class->table }->{ $event } ||= [ ];
  push @{
    $class->_triggers->{ $class->table }->{ $event }
  }, $handler;
}# end add_trigger()


#==============================================================================
sub dbi_commit
{
  my $s = shift;
  $s->_dbh->commit;
}# end dbi_commit()


#==============================================================================
sub dbi_rollback
{
  my $s = shift;
  $s->_dbh->rollback;
}# end dbi_rollback()


#==============================================================================
sub discard_changes
{
  my $s = shift;
  
  $s = ref($s)->retrieve( $s->id );
}# end discard_changes()


#==============================================================================
sub _call_triggers
{
  my ($s, $event) = @_;
  
  my $handlers = $s->_triggers->{ $s->table }->{ $event };
  foreach(  @$handlers )
  {
    eval {
      $_->( $s );
      1;
    } or confess $@;
  }# end foreach()
}# end _call_triggers()


#==============================================================================
sub AUTOLOAD
{
  my $s = shift;
  our $AUTOLOAD;
  my ($name) = $AUTOLOAD =~ m/([^:]+)$/;

  if( my ($col) = grep { $_ eq $name } $s->_columns_all )
  {
    if( @_ )
    {
      $s->{__Changed} ||= { };
      $s->{__Changed}->{$name} = {
        oldval => $s->{$name}
      };
      return $s->{$name} = shift;
    }
    else
    {
      return $s->{$name};
    }# end if()
  }
  else
  {
    my $class = ref($s) ? ref($s) : $s;
    confess "Uknown field or method '$name' for class $class";
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
  
  $s->dbi_commit unless $s->_dbh->{AutoCommit};
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

=head1 EXPERIMENTAL STATUS

B<**NOTE**:> This module is still under development.  It is likely to change
in dramatic ways without any warning.

As is, this module should not (yet) be used in a production environment until after v1.000.

=head1 SYNOPSIS

  package My::Model;
  
  use base 'Class::DBI::Lite';
  
  __PACKAGE__->connection(
    $Config->settings->dsn,
    $Config->settings->username,
    $Config->settings->password,
  );

Then, elsewhere...

  # Change the connection:
  My::Model->connection( @dsn );
  
  my $users = My::User->retrieve_all;
  
  My::Model->connection( @other_dsn );
  my $other_users = My::User->retrieve_all;

=head1 DESCRIPTION

This module is intended to serve as a drop-in replacement for the venerable Class::DBI
when many features of Class::DBI are simply not needed, or when Ima::DBI's quirks
are not wanted.

=head1 SEE ALSO

L<Class::DBI>

=head1 TODO

=over 4

=item * Documentation

=item * Near-100% code coverage

=item * Thorough code profiling

=item * Examples

=back

=head1 AUTHOR

John Drago <jdrago_999@yahoo.com>.

=head1 LICENSE AND COPYRIGHT

Copyright 2008 John Drago <jdrago_999@yahoo.com>.  All rights reserved.

This software is Free software and may be used and distributed under the same 
terms as perl itself.

=cut

