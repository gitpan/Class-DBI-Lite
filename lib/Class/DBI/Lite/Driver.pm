
package Class::DBI::Lite::Driver;

use strict;
use warnings 'all';
use Carp 'confess';

sub new
{
  my ($class, %args) = @_;
  
  $args{root}
    or confess "Usage: $class\->new( root => ... )";
  return bless \%args, $class;
}# end new()

sub set_up_table;
sub root { $_[0]->{root} }

1;# return true:

