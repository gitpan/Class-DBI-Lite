
package Class::DBI::Lite::RootMeta;

use strict;
use warnings 'all';

our %instances = ( );


#==============================================================================
sub new
{
  my ($s, $dsn) = @_;
  
  my $key = join ':', @$dsn;
  if( my $inst = $instances{$key} )
  {
    return $inst;
  }
  else
  {
    return $instances{$key} = bless {
      dsn           => $dsn,    # Global
      schema        => $dsn->[0], # Global
    }, $s;
  }# end if()
}# end new()

sub dsn     { my $s = shift; @_ ? $s->{dsn}     = shift : $s->{dsn} }
sub schema  { my $s = shift; @_ ? $s->{schema}  = shift : $s->{schema} }



1;# return true:

