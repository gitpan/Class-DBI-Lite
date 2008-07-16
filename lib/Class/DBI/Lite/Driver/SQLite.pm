
package Class::DBI::Lite::Driver::SQLite;

use strict;
use warnings 'all';
use base 'Class::DBI::Lite::Driver';
use Carp 'confess';

#==============================================================================
sub set_up_table
{
  my $s = shift;
  
  # Get our columns:
  my $table = shift;
  my $sth = $s->root->_dbh->prepare(<<"");
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
  
  $s->root->columns( Primary => $PK );
  $s->root->columns( All => @cols );
  1;
}# end set_up_table()


#==============================================================================
sub get_last_insert_id
{
  $_[0]->root->_dbh->func('last_insert_rowid');
}# end get_last_insert_id()

1;# return true:

