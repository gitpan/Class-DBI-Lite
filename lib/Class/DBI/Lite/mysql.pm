
package Class::DBI::Lite::mysql;

use strict;
use warnings 'all';
use base 'Class::DBI::Lite';
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
sub get_last_insert_id
{
  $_[0]->db_Main->{mysql_insertid};
}# end get_last_insert_id()

1;# return true:

