
package My::City;

use strict;
use warnings 'all';
use base 'My::Model';

__PACKAGE__->set_up_table('cities');


__PACKAGE__->has_a(
  state =>
    'My::State' =>
      'state_id'
);

1;# return true:

