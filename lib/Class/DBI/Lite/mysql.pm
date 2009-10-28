
package Class::DBI::Lite::mysql;

use strict;
use warnings 'all';
use base 'Class::DBI::Lite';
use Class::DBI::Lite::TableInfo;
use Carp 'confess';


#==============================================================================
sub set_up_table
{
  my $s = shift;
  
  # Get our columns:
  my $table = shift;
  $s->_init_meta( $table );
  $s->after_set_up_table;
  1;
}# end set_up_table()


#==============================================================================
sub get_meta_columns
{
  my ($s, $schema, $table) = @_;
  
  ($schema) = $schema =~ m/DBI\:mysql\:([^:]+)/;
  # Get our columns:
  my $sth = $s->db_Main->prepare(<<"");
    SELECT *
    FROM information_schema.columns
    WHERE table_schema = ?
    AND table_name = ?

  # Simple discovery of fields and PK:
  $sth->execute( $schema, $table );
  my @cols = ( );
  my $PK;
  while( my $rec = $sth->fetchrow_hashref )
  {
    $rec->{ lc($_) } = delete($rec->{$_}) foreach keys(%$rec);
    # Is this the primary column?:
    $PK = $rec->{column_name}
      if  $rec->{column_key} &&
          lc($rec->{column_key}) eq 'pri';
    push @cols, $rec->{column_name};
  }# end while()
  $sth->finish();
  
  confess "Table " . $schema . ".$table doesn't exist or has no columns"
    unless @cols;
  
  return {
    Primary   => [ $PK ],
    Essential => \@cols,
    All       => \@cols,
  };
  1;
}# end set_up_table()


#==============================================================================
sub after_set_up_table { }


#==============================================================================
sub get_table_info
{
  my $s = shift;
  my $class = ref($s) || $s;
  my $cur = $class->db_Main->prepare("SHOW COLUMNS FROM " . $class->table);
  $cur->execute;
  
  my $info = Class::DBI::Lite::TableInfo->new( $class->table );
  
  my %key_types = (
    UNI => 'unique',
    PRI => 'primary_key'
  );
  
  while( my $res = $cur->fetchrow_hashref )
  {
    $res->{lc($_)} = delete($res->{$_}) foreach keys(%$res);
    
    my ($type) = $res->{type} =~ m/^([^\(\)]+)/;
    my $length;
    if( $type =~ m/(text|varchar|char)/i )
    {
      ($length) = $res->{type} =~ m/\((\d+)\)/;
    }# end if()
    
    # If it's an enum, we want to provide a list of possible values:
    my %enum_args = ( );
    if( lc($type) eq 'enum' )
    {
      my @vals = $res->{type} =~ m/\(('([^']+',?)\)/g;
      $enum_args{enum_values} = \@vals;
    }#end if()
    
    $info->add_column(
      name          => $res->{field},
      type          => lc($type),
      length        => $length,
      is_pk         => $res->{key} eq 'PRI' ? 1 : 0,
      is_nullable   => $res->{null} eq 'NO' ? 0 : 1,
      default_value => $res->{default},
      key           => $key_types{ $res->{key} },
      %enum_args,
    );
  }# end while()
  $cur->finish;
  
  return $info;
}# end get_table_info()


#==============================================================================
sub get_last_insert_id
{
  $_[0]->db_Main->{mysql_insertid};
}# end get_last_insert_id()

1;# return true:

