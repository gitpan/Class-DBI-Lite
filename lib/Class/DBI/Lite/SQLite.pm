
package Class::DBI::Lite::SQLite;

use strict;
use warnings 'all';
use base 'Class::DBI::Lite';
use Carp 'confess';


#==============================================================================
sub set_up_table
{
  my $s = shift;
  
  $s->_init_state;
  
  # Get our columns:
  my $table = shift;
  $s->_state->{table} = $table;
  my $sth = $s->db_Main->prepare(<<"");
    PRAGMA table_info( '$table' )

  # Simple discovery of fields and PK:
  $sth->execute( );
  my @cols = ( );
  my $PK;
  while( my $rec = $sth->fetchrow_hashref )
  {
    # Is this the primary column?:
    $PK = $rec->{name}
      if  $rec->{pk};
    push @cols, $rec->{name};
  }# end while()
  $sth->finish();
  
  confess "Table $table doesn't exist or has no columns"
    unless @cols;
  
  $s->columns( Primary => $PK );
  $s->columns( Essential => @cols );
  $s->columns( All => @cols );
  1;
}# end set_up_table()


#==============================================================================
sub get_last_insert_id
{
  $_[0]->db_Main->func('last_insert_rowid');
}# end get_last_insert_id()

1;# return true:

