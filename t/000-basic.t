#!/usr/bin/env perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';
use lib qw( t/lib lib );

use_ok('My::Model');
use_ok('My::User');
use_ok('My::State');
use_ok('My::City');


