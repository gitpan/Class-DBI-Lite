#!/usr/bin/env perl -w

package My::Model;

use strict;
use warnings 'all';
use base 'Class::DBI::Lite';
#use Class::DBI::AbstractSearch;
#use Class::DBI::Plugin::CountSearch;
#use Class::DBI::Plugin::AbstractCount;

__PACKAGE__->connection(
  'DBI:SQLite:dbname=t/testdb',
  '',
  ''
);

package My::User;

use strict;
use warnings 'all';
use base 'My::Model';

__PACKAGE__->set_up_table('users');

__PACKAGE__->add_trigger( before_update => sub {
  my $s = shift;
});

__PACKAGE__->add_trigger( after_update => sub {
  my $s = shift;
});

__PACKAGE__->add_trigger( before_create => sub {
  my $s = shift;
});

__PACKAGE__->add_trigger( after_create => sub {
  my $s = shift;
});

__PACKAGE__->add_trigger( before_delete => sub {
  my $s = shift;
});

__PACKAGE__->add_trigger( after_delete => sub {
  my $s = shift;
});

__PACKAGE__->add_trigger( after_delete => sub {
  my $s = shift;
});

package My::State;

use base 'My::Model';

__PACKAGE__->set_up_table('states');

__PACKAGE__->has_many(
  cities =>
    'My::City' =>
      'state_id'
);

package My::City;

use base 'My::Model';

__PACKAGE__->set_up_table('cities');

__PACKAGE__->has_a(
  state =>
    'My::State' =>
      'state_id'
);

#sub state { My::State->retrieve( shift->state_id ) }


package main;

use Test::More 'no_plan';


is(
  My::User->table => 'users',
);

is(
  My::User->columns('Primary') => 'user_id'
);

# create:
my $userID;
{
  $_->delete foreach My::User->search( user_first_name => 'firstname' );
  my $user = My::User->create({
    user_first_name => 'firstname',
    user_last_name  => 'lastname',
    user_email      => 'test@test.com',
    user_password   => 'pass',
  });
  $userID = $user->id;
  
  isa_ok(
    $user => 'My::User'
  );
  ok(
    $user->id => "user.id exists"
  );
  is(
    $user->user_first_name => 'firstname'
  );
}


# uniqueness of objects in memory:
{
  $_->delete foreach My::State->retrieve_all;
  my $A = My::State->create({
    state_name => 'Colorado',
    state_abbr => 'CO'
  });
  my ($B) = My::State->search( state_abbr => 'CO' );
  $B->state_abbr('IA');
  is(
    $A->state_abbr => $B->state_abbr,
    'uniqueness of objects in memory works!'
  );
  $A->delete;
  isa_ok(
    $B => 'Class::DBI::Lite::Object::Has::Been::Deleted'
  );
  $A = My::State->create({
    state_name => 'Colorado',
    state_abbr => 'CO'
  });
  for( 1...10 )
  {
    $A->add_to_cities({
      city_name => 'Denver' . $_
    });
  }# end for()
  my $cities = $A->cities;
  is(
    $cities->count => 10
  );
  $A->delete;
  is(
    scalar( grep { "$_" } @{$cities->{data}} ) => 0
  );
}

# retrieve:
{
  my $user = My::User->retrieve( $userID );
  isa_ok(
    $user => 'My::User'
  );
  is(
    $user->id => $userID,
    "user.id is correct"
  );
}

# retrieve_all:
{
  my $users = My::User->retrieve_all;
  isa_ok(
    $users => 'Class::DBI::Lite::Iterator'
  );
  ok( $users->count, "users.count" );
  isa_ok(
    $users->first => 'My::User'
  );

  while( my $user = $users->next )
  {
    isa_ok( $user => 'My::User' );
    ok( $user->id );
  }# end while()
}

# search:
{
  my $users = My::User->search(
    user_first_name => 'firstname'
  );
  isa_ok(
    $users => 'Class::DBI::Lite::Iterator'
  );
  ok( $users->count, "users.count" );
  isa_ok(
    $users->first => 'My::User'
  );

  while( my $user = $users->next )
  {
    isa_ok( $user => 'My::User' );
    ok( $user->id );
  }# end while()
}

# count_search:
{
  my $count = My::User->count_search(
    user_first_name => 'firstname'
  );
  is( $count => 1 );
}

# search_like:
{
  my $users = My::User->search_like(
    user_first_name => 'firs%'
  );
  isa_ok(
    $users => 'Class::DBI::Lite::Iterator'
  );
  ok( $users->count, "users.count" );
  isa_ok(
    $users->first => 'My::User'
  );

  while( my $user = $users->next )
  {
    isa_ok( $user => 'My::User' );
    ok( $user->id );
  }# end while()
}

# count_search_like:
{
  my $count = My::User->count_search_like(
    user_first_name => 'firs%'
  );
  is( $count => 1 );
}

# search_where:
{
  my $users = My::User->search_where({
    user_id => { '!=' => 0 }
  }, {
    order_by => 'user_first_name ASC'
  }, {
    limit => '0, 10'
  });
  isa_ok(
    $users => 'Class::DBI::Lite::Iterator'
  );
  ok( $users->count, "users.count" );
  isa_ok(
    $users->first => 'My::User'
  );

  while( my $user = $users->next )
  {
    isa_ok( $user => 'My::User' );
    ok( $user->id );
  }# end while()
}

# count_search_where:
{
  my $count = My::User->count_search_where({
    user_first_name => { LIKE => 'firs%' }
  });
  is( $count => 1 );
}

# update:
{
  my $user = My::User->retrieve_all->first;
  $user->user_first_name( 'w00t' );
  $user->update;
  undef( $user );
  $user = My::User->retrieve_all->first;
  is(
    $user->user_first_name => 'w00t'
  );
  $user->user_first_name( 'firstname' );
  $user->update;
  undef( $user );
  $user = My::User->retrieve_all->first;
  is(
    $user->user_first_name => 'firstname'
  );
}

# load-test:
{
  $_->delete foreach My::State->retrieve_all;
  is(
    My::State->retrieve_all->count => 0
  );
  my $state = My::State->create({
    state_name => 'Colorado',
    state_abbr => 'CO'
  });
  for( 1...1_000 )
  {
    my $city = $state->add_to_cities({
      city_name => 'Denver' . $_
    });
    isa_ok(
      $city => 'My::City'
    );
  }# end for()
  is(
    $state->cities->count => 1000
  );
  $state->delete;
  is(
    My::State->retrieve_all->count => 0
  );
}

# has_many:
{
  $_->delete foreach My::State->retrieve_all;
  my $state = My::State->create({
    state_name => 'Colorado',
    state_abbr => 'CO'
  });
  for( 1...10 )
  {
    $state->add_to_cities({
      city_name => 'Denver' . $_
    });
  }# end for()
  my $cities = $state->cities;
  ok( $cities );
  ok( $cities->count );
  isa_ok(
    $cities->first => 'My::City'
  );
  isa_ok(
    $cities->first->state => 'My::State'
  );
  is_deeply(
    $cities->first->state => My::State->retrieve( 1 )
  );
  while( my $city = $cities->next )
  {
    is(
      $city->state->state_id => $state->state_id
    );
  }# end while()
}

# connection-switching:
{
  My::User->connection(
    'DBI:SQLite:dbname=t/testdb',
    '',
    ''
  );
  my $user = My::User->retrieve_all->first;
#  use Data::Dumper;
#  warn Dumper( $user );
  My::User->connection(
    'DBI:SQLite:dbname=t/testdb',
    '',
    ''
  );
  $user = My::User->retrieve_all->first;
#  use Data::Dumper;
#  warn Dumper( $user );
#  $user->user_first_name( 'changed' );
}



