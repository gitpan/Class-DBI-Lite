#!/usr/bin/perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';
use lib qw( lib t/lib );
use Data::Dumper;

use_ok( 'My::State' );

my $expected = bless( {
  'columns' => [
    bless( {
      'is_pk'         => 0,
      'length'        => '2',
      'default_value' => undef,
      'name'          => 'state_abbr',
      'type'          => 'char',
      'is_nullable'   => 1,
      'key'           => undef
    }, 'Class::DBI::Lite::ColumnInfo' ),
    bless( {
      'is_pk'         => 1,
      'length'        => undef,
      'default_value' => undef,
      'name'          => 'state_id',
      'type'          => 'integer',
      'is_nullable'   => 1,
      'key'           => undef
    }, 'Class::DBI::Lite::ColumnInfo' ),
    bless( {
      'is_pk'         => 0,
      'length'        => '50',
      'default_value' => undef,
      'name'          => 'state_name',
      'type'          => 'varchar',
      'is_nullable'   => 1,
      'key'           => undef
    }, 'Class::DBI::Lite::ColumnInfo' )
  ],
  'table' => 'states'
}, 'Class::DBI::Lite::TableInfo' );

is_deeply( My::State->get_table_info, $expected );


