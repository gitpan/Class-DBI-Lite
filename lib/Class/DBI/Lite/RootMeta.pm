
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


#==============================================================================
#sub AUTOLOAD
#{
#  my $s = shift;
#  our $AUTOLOAD;
#  my ($key) = $AUTOLOAD =~ m/([^:]+)$/;
#  
#  # Universal setter/getter:
#  @_ ? $s->{$key} = shift : $s->{$key};
#}# end AUTOLOAD()

1;# return true:

