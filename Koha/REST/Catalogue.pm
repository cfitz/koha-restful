package Koha::REST::Catalogue;

use base 'CGI::Application';
use Modern::Perl;

# remove these before checking into repo
use lib ( "/Users/chrisfitzpatrick/code/Koha/" );
use Data::Dumper;

use Koha::REST::Response qw(format_response response_boolean format_error);
use C4::Context;
use C4::Reserves;
use C4::Items;
use C4::Biblio;
use C4::Branch;
use C4::Members;

sub setup {
    my $self = shift;
    $self->run_modes(
        'get_biblio' => 'rm_get_biblio',
		'get_biblio_items' => 'rm_get_biblio_items',
        'biblio_is_holdable' => 'rm_biblio_is_holdable',
		'biblio_hold' => 'rm_hold_biblio',
		'item_hold' => 'rm_hold_item',
        'item_is_holdable' => 'rm_item_is_holdable',
        'get_biblio_items_holdable_status' => 'rm_get_biblio_items_holdable_status',
				'items' => 'rm_items',
    );
}

my @items_columns;
sub items_columns {
    if (scalar @items_columns == 0) {
        @items_columns = keys %{C4::Context->dbh->selectrow_hashref("
            SELECT * FROM items LIMIT 1")};
    }
    return @items_columns;
}

sub rm_items {
	my $self = shift;
	my $q = $self->query();
	my @biblionumbers =  split(",", $q->param('biblionumbers') );
  my $results;
  my $itemnumbers = C4::Items::get_itemnumbers_of( @biblionumbers);
  foreach my $bib ( keys %$itemnumbers ) {
					my $nums =  $itemnumbers->{$bib};
  	  		$results->{$bib} = C4::Items::GetItemInfosOf( @$nums );
 	}
	return format_response($self, $results);
	
}




# get a biblio record for a biblio
sub rm_get_biblio {
	my $self = shift;
	my $biblionumber = $self->param('biblionumber');
    my $biblioitem = ( C4::Biblio::GetBiblioItemByBiblioNumber( $biblionumber, undef ) )[0];
    if ( not $biblioitem->{'biblionumber'} ) {
       return format_error( $self, '404', ['Biblio Record Not Found'] );
    }

   	my $embed_items = 1;
    my $record = C4::Biblio::GetMarcBiblio($biblionumber, $embed_items);
    if ($record) {
        $biblioitem->{marcxml} = $record->as_xml_record();
    }

    # We don't want MARC to be displayed
    delete $biblioitem->{'marc'};

    # Get most of the needed data
    my $biblioitemnumber = $biblioitem->{'biblioitemnumber'};
    my @reserves         = C4::Reserves::GetReservesFromBiblionumber( $biblionumber, undef, undef );
    my $issues           = C4::Circulation::GetBiblioIssues($biblionumber);

    my $items            = C4::Items::GetItemsByBiblioitemnumber($biblioitemnumber);



	# We loop over the items to clean them
    foreach my $item (@$items) {

         # This hides additionnal XML subfields, we don't need these info
         delete $item->{'more_subfields_xml'};

         # Display branch names instead of branch codes
         $item->{'homebranchname'}    = C4::Branch::GetBranchName( $item->{'homebranch'} );
         $item->{'holdingbranchname'} = C4::Branch::GetBranchName( $item->{'holdingbranch'} );
     }

# Hashref building...
      $biblioitem->{'items'}->{'item'}       = $items;
      $biblioitem->{'reserves'}->{'reserve'} = $reserves[1];
      $biblioitem->{'issues'}->{'issue'}     = $issues;    
    
	return format_response($self, $biblioitem);
	
	
}


# return the list of all items for one biblio
sub rm_get_biblio_items {
    my $self = shift;
    my $biblionumber = $self->param('biblionumber');

    my $response = [];
    my @all_items = C4::Items::GetItemsInfo($biblionumber);
    foreach my $item (@all_items) {
        my $holdingbranchname = C4::Branch::GetBranchName($item->{holdingbranch});
        my $homebranchname = C4::Branch::GetBranchName($item->{homebranch});
        my $r = {
            (map { +"$_" => $item->{$_} } items_columns),
            holdingbranchname => $holdingbranchname,
            homebranchname => $homebranchname,
            withdrawn => $item->{wthdrawn},
            date_due => $item->{datedue},
        };
        push @$response, $r;
    }

    return format_response($self, $response);
}

# check if a biblio is holdable
sub rm_biblio_is_holdable {
    my $self = shift;
    my $biblionumber = $self->param('biblionumber');

    my $q = $self->query();
    my $borrowernumber = $q->param('borrowernumber');
    my $itemnumber = $q->param('itemnumber');

    my $can_reserve;
    if ($borrowernumber) {
        if ($itemnumber) {
            $can_reserve = C4::Reserves::CanItemBeReserved($borrowernumber, $itemnumber);
        } else {
            $can_reserve = C4::Reserves::CanBookBeReserved($borrowernumber, $biblionumber);
        }
    } else {
        $can_reserve = 1;
    }

    my $response = {
        is_holdable => response_boolean($can_reserve),
        reasons => ($can_reserve) ? [] : [ "No reasons..." ],
    };
    return format_response($self, $response);
}

# return the status (holdable or not) of all items of a biblio
sub rm_get_biblio_items_holdable_status {
    my $self = shift;
    my $biblionumber = $self->param('biblionumber');

    my $borrower = get_borrower($self); 
   	my $borrowernumber = $borrower->{borrowernumber};

    my $response = {};
    my $itemnumbers = C4::Items::get_itemnumbers_of($biblionumber);
    if ($itemnumbers->{$biblionumber}) {
        foreach my $itemnumber (@{ $itemnumbers->{$biblionumber} }) {
            my $is_holdable;
            if ($borrowernumber) {
                my $can_reserve = C4::Reserves::CanItemBeReserved($borrowernumber, $itemnumber);
                # This shouldn't be here. It should be in the C4::Reserves::CanItemBeReserved function. But that's how koha works.
                my $available = C4::Reserves::IsAvailableForItemLevelRequest($itemnumber);
                $is_holdable = $can_reserve && $available;
            } else {
                $is_holdable = 0;
            }
            $response->{$itemnumber} = {
                is_holdable => response_boolean($is_holdable),
                reasons => [],
            };
        }
    }

    return format_response($self, $response);
}

# check if an item is holdable
sub rm_item_is_holdable {
    my $self = shift;
    my $itemnumber = $self->param('itemnumber');

    my $q = $self->query();
    my $user_name = $q->param('user_name');
    my $borrower = C4::Members::GetMember(userid => $user_name);
    my $borrowernumber = $borrower->{borrowernumber};

    my $can_reserve;
    if ($borrowernumber) {
        $can_reserve = C4::Reserves::CanItemBeReserved($borrowernumber, $itemnumber);
    } else {
        $can_reserve = 0;
    }

    my $response = {
        is_holdable => response_boolean($can_reserve),
        reasons => ($can_reserve) ? [] : [ "No reasons..." ],
    };
    return format_response($self, $response);
}


# hold a title for a patron. 
sub rm_hold_biblio {
    my $self = shift;
	my $biblionumber = $self->param('biblionumber');
    my $q = $self->query;

	my $borrower = get_borrower($q);
	my $borrowernumber = $borrower->{borrowernumber}; #make sure we have the right borrowernumber
    
    return format_error($self, '404', ['Patron Not Found' ]) unless $borrowernumber;

  
    # Get the biblio record, or return an error code
    my $biblio = C4::Reserves::GetBiblio( $biblionumber );
    return format_error($self, '404',  [ 'Record Not Found']  ) unless $$biblio{biblionumber};
    
    my $title = $$biblio{title};

    # Check if the biblio can be reserved
    my $canreserve =    C4::Reserves::CanBookBeReserved( $borrowernumber, $biblionumber );
    return format_error($self, '401', ["Biblio $biblionumber Cannot be Reserved by $borrowernumber "]) unless $canreserve;

    my $branch;

    # Pickup branch management
    if ( $self->param('pickup_location') ) {
        $branch = $self->param('pickup_location');
        my $branches = GetBranches;
     #   return { code => 'LocationNotFound' } unless $$branches{$branch};
    } else { # if the request provide no branch, use the borrower's branch
        $branch = $$borrower{branchcode};
    }

    # Add the reserve
    #          $branch, $borrowernumber, $biblionumber, $constraint, $bibitems,  $priority, $notes, $title, $checkitem,  $found
   C4::Reserves::AddReserve( $branch, $borrowernumber, $biblionumber, 'a', undef, 1, undef, $title, undef, undef );

    # Hashref building
    my $out;
    $out->{'title'}           = $title;
    $out->{'pickup_location'} = GetBranchName($branch);
	$out->{'borrowernumber'} = $borrowernumber;
	$out->{"biblionumber"} = $biblionumber;
	$out->{"title"} = $title;
    # TODO $out->{'date_available'}  = '';

    return format_response($self, $out);
	
}



# hold an item for a patron.
sub rm_hold_item {
    my $self = shift;
	my $itemnumber = $self->param('itemnumber');
	
   
    my $q = $self->query;
	my $borrower = get_borrower($q);

	my $borrowernumber = $borrower->{borrowernumber};
    return format_error($self, '404', [ 'Patron Not Found' ]) unless $borrowernumber;

    # Get the biblio or return an error code
    my $biblio = C4::Biblio::GetBiblioFromItemNumber($itemnumber, undef);
	my $biblionumber = $$biblio{biblionumber};
    return format_error( $self, '404', [ 'RecordNotFound'] ) unless $biblionumber;

    my $title = $$biblio{title};

    # Get the item or return an error code
    my $item = C4::Reserves::GetItem( $itemnumber );
    return format_error( $self, '404', [ 'RecordNotFound'] ) unless $$item{itemnumber};

    # If the biblio does not match the item, return an error code
    return format_error( $self, '404', [ 'RecordNotFound'] )  if $$item{biblionumber} ne $$biblio{biblionumber};

    # Check for item disponibility
    my $canitembereserved = C4::Reserves::CanItemBeReserved( $borrowernumber, $itemnumber );
    my $canbookbereserved = C4::Reserves::CanBookBeReserved( $borrowernumber, $biblionumber );
    return format_error( $self, "412", ["Item $itemnumber with $biblionumber bib number is Not Holdable by Patron $borrowernumber"] ) unless $canbookbereserved and $canitembereserved;

    my $branch;

    # Pickup branch management
    if ( $self->param('pickup_location') ) {
        $branch = $self->param('pickup_location');
        my $branches = GetBranches();
        return format_error($self, "404",  ['Pickup Location Not Found'] ) unless $$branches{$branch};
    } else { # if the request provide no branch, use the borrower's branch
        $branch = $$borrower{branchcode};
    }

    my $rank;
    my $found;

    # Get rank and found
    $rank = '0' unless C4::Context->preference('ReservesNeedReturns');
    if ( $branch && $item->{'holdingbranch'} eq $branch ) {
        $found = 'W' unless C4::Context->preference('ReservesNeedReturns');
    }

    # Add the reserve
    # $branch,$borrowernumber,$biblionumber,$constraint,$bibitems,$priority,$resdate,$expdate,$notes,$title,$checkitem,$found
    C4::Reserves::AddReserve( $branch, $borrowernumber, $biblionumber, 'a', undef, $rank, '', '', '', $title, $itemnumber, $found );

   # Hashref building
    my $out;
    $out->{'title'}           = $title;
    $out->{'pickup_location'} = GetBranchName($branch);
	$out->{'borrowernumber'} = $borrowernumber;
	$out->{"biblionumber"} = $biblionumber;
	$out->{"itemnumber"} = $item->{'itemnumber'};
	$out->{"title"} = $title;
   
    return format_response($self, $out);
}

# this is a convience method to get the borrower information if the user_name o borrowernumber has been passed in a query
sub get_borrower { 
	my $q = $_[0];
	
   	my $borrowernumber = $q->param('borrowernumber');
	my $user_name = $q->param('user_name');
	my $borrower;
    if ($borrowernumber) {
		 $borrower = C4::Members::GetMember(borrowernumber => $borrowernumber);
    } else {
		$borrower = C4::Members::GetMember(userid => $user_name);
	}

	return $borrower;
}


1;
