
package Class::DBI::Lite::Iterator;

use strict;
use warnings 'all';

#==============================================================================
sub new
{
  my ($class, $data) = @_;
  
  return bless {
    data => $data,
    count => scalar(@$data),
    idx   => 0
  }, $class;
}# end new()


#==============================================================================
sub first
{
  $_[0]->{data}->[0];
}# end first()


#==============================================================================
sub next
{
  my $s = shift;
  return unless $s->{idx} < $s->{count};
  $s->{data}->[ $s->{idx}++ ];
}# end next()


#==============================================================================
sub count
{
  $_[0]->{count};
}# end count()


#==============================================================================
sub reset
{
  $_[0]->{idx} = 0;
}# end reset()

1;# return true:

__END__

=pod

=head1 NAME

Class::DBI::Lite::Iterator - Simple iterator for Class::DBI::Lite

=head1 EXPERIMENTAL STATUS

B<**NOTE**:> This module is still under development.  It is likely to change
in dramatic ways without any warning.

=head1 SYNOPSIS

  # Get an iterator somehow:
  my $iter = My::User->retrieve_all;
  
  my $user = $iter->first;
  
  my $record_count = $iter->count;
  
  while( my $user = $iter->next )
  {
    ...
  }# end while()
  
  # We can reset the iterator to go back to the beginning:
  $iter->reset;
  print $_->id . "\n" while $_ = $iter->next;

=head1 DESCRIPTION

Provides a simple iterator-based approach to Class::DBI::Lite resultsets.

=head1 PUBLIC PROPERTIES

=head2 count

Returns the number of records in the Iterator.

=head1 PUBLIC METHODS

=head2 next

Returns the next object in the series, or undef.

Moves the internal cursor to the next object if one exists.

=head2 reset

Resets the internal cursor to the first object if one exists.

=head1 SEE ALSO

L<Class::DBI:Lite>

=head1 AUTHOR

John Drago <jdrago_999@yahoo.com>.

=head1 LICENSE AND COPYRIGHT

Copyright 2008 John Drago <jdrago_999@yahoo.com>.  All rights reserved.

This software is Free software and may be used and distributed under the same 
terms as perl itself.

=cut

