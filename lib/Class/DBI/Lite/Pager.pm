
package Class::DBI::Lite::Pager;

use strict;
use warnings 'all';


sub new
{
  my ($class, %args) = @_;
  
  return bless {
    data_sql      => undef,
    count_sql     => undef,
    sql_args      => [ ],
    where         => undef,
    order_by      => undef,
    class         => undef,
    page_number   => 1,
    page_size     => 10,
    total_items   => 0,
    start_item    => 1,
    stop_item     => 0,
    %args,
    _fetched_once => 0,
  }, $class;
}# end new()


# Public read-only properties:
sub page_number { shift->{page_number} }
sub page_size   { shift->{page_size} }
sub total_items { shift->{total_items} }
sub total_pages { shift->{total_pages} }
sub start_item  { shift->{start_item} }
sub stop_item   { shift->{stop_item} }
sub has_next { $_[0]->{page_number} < $_[0]->{total_pages} }
sub has_prev { shift->{page_number} > 1 }

*items = \&next_page;

sub next_page
{
  my $s = shift;
  
  return unless $s->has_next;
  
  if( $s->{_fetched_once}++ )
  {
    $s->{page_number}++;
  }# end if()
  
  $s->{stop_item} = $s->page_number * $s->page_size;
  $s->{stop_item} = $s->total_items if $s->stop_item > $s->total_items;
  $s->{start_item} = ( $s->page_number - 1 ) * $s->page_size + 1;
  
  my $offset = $s->_offset;
  my $limit = " LIMIT $offset, @{[ $s->{page_size} ]} ";
  
  if( $s->{data_sql} )
  {
    my $sth = $s->{class}->db_Main->prepare( "$s->{data_sql} $limit" );
    $sth->execute( @{ $s->{sql_args} } );
    return $s->{class}->sth_to_objects( $sth );
  }
  else
  {
    return $s->{class}->search_where(
      $s->{where},
      {
        order_by  => "$s->{order_by} $limit",
      }
    );
  }# end if()
}# end next_page()


sub prev_page
{
  my $s = shift;
  
  return unless $s->has_prev;
  
  $s->{page_number}-- if $s->{_fetched_once}++;
  $s->{stop_item} = $s->page_number * $s->page_size;
  $s->{stop_item} = $s->total_items if $s->stop_item > $s->total_items;
  $s->{start_item} = ( $s->page_number - 1 ) * $s->page_size + 1;
  $s->{start_item} = 0 if $s->{start_item} < 0;
  
  my $offset = $s->_offset;
  my $limit = " LIMIT $offset, @{[ $s->{page_size} ]} ";
  
  if( $s->{data_sql} )
  {
    my $sth = $s->{class}->db_Main->prepare( "$s->{data_sql} $limit" );
    $sth->execute( @{ $s->{sql_args} } );
    return $s->{class}->sth_to_objects( $sth );
  }
  else
  {
    return $s->{class}->search_where(
      $s->{where},
      {
        order_by  => "$s->{order_by} $limit",
      }
    );
  }# end if()
}# end prev_page()


sub _offset
{
  my $s = shift;
  $s->{page_number} == 1 ? 0 : ($s->{page_number} - 1) * $s->{page_size};
}# end _offset()

1;# return true:

=pod

=head1 NAME

Class::DBI::Lite::Pager - Page through your records, easily.

=head1 SYNOPSIS

=head2 Paged Navigation Through Large Datasets

  # Say we're on page 1 of a list of all 'Rock' artists:
  my $pager = My::Artist->pager({
    genre => 'Rock',
  }, {
    order_by    => 'name ASC',
    page_number => 1,
    page_size   => 20,
  });

  # -------- OR -----------
  my $pager = My::Artist->sql_pager({
    data_sql  => "SELECT * FROM artists WHERE genre = ?",
    count_sql => "SELECT COUNT(*) FROM artists WHERE genre = ?",
    sql_args  => [ 'Rock' ],
  }, {
    page_number => 1,
    page_size   => 20,
  });
  
  # Get the first page of items from the pager:
  my @artists = $pager->items;
  
  # Is the a 'previous' page?:
  if( $pager->has_prev ) {
    print "Prev page number is " . ( $pager->page_number - 1 ) . "\n";
  }
  
  # Say where we are in the total scheme of things:
  print "Page " . $pager->page_number . " of " . $pager->total_pages . "\n";
  print "Showing items " . $pager->start_item . " through " . $pager->stop_item . " out of " . $pager->total_items . "\n";
  
  # Is there a 'next' page?:
  if( $pager->has_next ) {
    print "Next page number is " . ( $pager->page_number + 1 ) . "\n";
  }

=head2 Fetch Huge Datasets in Small Chunks

  # Fetch 300,000,000 records, 100 records at a time:
  my $pager = My::Human->pager({
    country => 'USA'
  }, {
    order_by    => 'last_name, first_name',
    page_size   => 100,
    page_number => 1,
  });
  while( my @people = $pager->next_page ) {
    # We only got 100 people, instead of killing the 
    # database by asking for 300M records all at once:
  }

=head1 DESCRIPTION

Paging through records should be easy.  C<Class::DBI::Lite::Pager> B<makes> it easy.



=head1 CAVEAT EMPTOR

This has been tested with MySQL 5.x and SQLite.  It should work with any database
that provides some kind of C<LIMIT index, offset> construct.

To discover the total number of pages and items, 2 queries must be performed:

=over 4

=item 1 First we do a C<SELECT COUNT(*) ...> to find out how many items there are in total.

=item 2 One or more queries to get the records you've requested.

If running 2 queries is going to cause your database server to catch fire, please consider rolling your own pager
or finding some other method of doing this.

=back

=head1 CONSTRUCTOR

=head2 new( page_number => 1, page_size => 10 )

Returns a new Pager object at the page number and page size specified.

=head1 PUBLIC PROPERTIES

=head2 page_number

Read only.  Returns the page number.

=head2 page_size

Read only.  Returns the page size.

=head2 total_pages

Read only.  Returns the total number of pages in the Pager.

=head2 total_items

Read only.  Returns the total number of records in all the pages combined.

=head2 start_item

Read only.  Returns the index of the first item in this page's records.

=head2 stop_item

Read only.  Returns the index of the last item in this page's records.

=head2 has_next

Read only.  Returns true or false depending on whether there are more pages B<after> the current page.

=head2 has_prev

Read only.  Returns true or false depending on whether there are more pages B<before> the current page.

=head1 PUBLIC METHODS

=head2 items( )

Returns the next page of results.  Same as calling C<next_page()>.  Purely for syntax alone.

=head2 next_page( )

Returns the next page of results.  If called in list context, returns an array.  If 
called in scalar context, returns a L<Class::DBI::Lite::Iterator>.

If there is not a next page, returns undef.

=head2 prev_page( )

Returns the previous page of results.  If called in list context, returns an array.  If 
called in scalar context, returns a L<Class::DBI::Lite::Iterator>.

If there is not a previous page, returns undef.

=head1 AUTHOR

Copyright John Drago <jdrago_999@yahoo.com>.  All rights reserved.

=head1 LICENSE

This software is B<Free> software and may be used and redistributed under the
same terms as perl itself.

=cut
