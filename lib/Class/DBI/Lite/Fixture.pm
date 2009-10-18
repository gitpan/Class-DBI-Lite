
package Class::DBI::Lite::Fixture;

use strict;
use warnings 'all';

my @destroys = ( );

my $_instance;


sub import
{
  my ($class, @fixtures) = @_;
  
  $_instance ||= bless { }, $class;
  
  map {
    my $setup = "setup_$_";
    my $destroy = "destroy_$_";
    push @destroys, sub { $class->$destroy };
    $class->$setup
  } @fixtures;
}# end import()


DESTROY
{
  map { eval { $_->() } } @destroys;
}# end DESTROY()

1;# return true:

=pod

=head1 NAME

Class::DBI::Lite::Fixture - Test fixtures for easy testing.

=head1 SYNOPSIS

=head2 In Your Test Fixture

  package My::Fixtures;

  use strict;
  use warnings 'all';
  use base 'Class::DBI::Lite::Fixture';
  use My::State;

  my @state_info = qw( AL:Alabama AK:Alaska AR:Arkansas );
  my @states = ( );

  sub setup_states {
    push @states, map {
      my ($abbr, $name) = split /\:/, $_;
      My::State->find_or_create(
        state_name  => $name,
        state_abbr  => $abbr,
      )
    } @state_info;
  }# end setup_states()

  sub destroy_states {
    map { eval{$_->delete} } @states;
  }# end destroy_states()

  1;# return true:

=head2 In Your Test File

  use strict;
  use warnings 'all';
  use Test::More 'no_plan';
  use lib qw( lib t/lib );
  
  # Setup your test fixtures:
  use My::Fixtures 'states';
  
  use_ok('My::State');
  is(
    My::State->count_search(state_abbr => 'AL') => 1
  );
  
  # The 'My::State' records are automatically deleted in 'destroy_states'!

=head1 DESCRIPTION

This module provides stubs for the use of "test fixtures" to test your code.

=head1 AUTHOR

Copyright John Drago <jdrago_999@yahoo.com>.  All rights reserved.

=head1 LICENSE

This software is Free software and may be used and redistributed under the
same terms as perl itself.

=cut

