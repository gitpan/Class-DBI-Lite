
package My::Model;

use strict;
use warnings 'all';
use base 'Class::DBI::Lite::SQLite';

__PACKAGE__->connection(
  'DBI:SQLite:dbname=t/testdb',
  '',
  ''
);

1;# return true:

