#!/usr/bin/env perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';
use lib qw( t/lib lib );

use_ok('My::Model');
use_ok('My::User');

$_->delete foreach My::User->retrieve_all;
My::User->create(
  user_first_name => 'firstname',
  user_last_name  => 'lastname',
  user_email      => 'test@test.com',
  user_password   => 'pass'
);

use_ok('My::State');

ok( My::State->retrieve_all->count );

my ($state) = My::State->retrieve_all;
$state->cities;
use_ok('My::City');


