#!/usr/bin/env perl -w

use strict;
use warnings 'all';
use lib qw( lib t/lib );
use My::Province;

use Test::More 'no_plan';

ok( my $provinces = My::Province->retrieve_all );



