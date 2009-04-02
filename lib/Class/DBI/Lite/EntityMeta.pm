
package Class::DBI::Lite::EntityMeta;

use strict;
use warnings 'all';

our %instances = ( );


#==============================================================================
sub new
{
  my ($s, $forClass, $schema, $entity) = @_;

  my $key = join ':', ( $schema, $entity );
  if( my $inst = $instances{$key} )
  {
    return $inst;
  }
  else
  {
    return $instances{$key} = bless {
      table         => $entity, # Class-based
      triggers      => {      # Class-based
        before_create => [ ],
        after_create  => [ ],
        before_update => [ ],
        after_update  => [ ],
        before_delete => [ ],
        after_delete  => [ ],
      },
      has_a_rels    => { },   # Class-based
      has_many_rels => { },   # Class-based,
      columns       => $forClass->get_meta_columns( $schema, $entity ),
    }, $s;
  }# end if()
}# end new()


#==============================================================================
sub AUTOLOAD
{
  my $s = shift;
  our $AUTOLOAD;
  my ($key) = $AUTOLOAD =~ m/([^:]+)$/;
  
  # Universal setter/getter:
  @_ ? $s->{$key} = shift : $s->{$key};
}# end AUTOLOAD()

1;# return true:

