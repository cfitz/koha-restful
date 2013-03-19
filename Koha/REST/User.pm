package Koha::REST::User;

use base 'CGI::Application';
use Modern::Perl;

# remove these before checking into repo
use lib ( "/Users/chrisfitzpatrick/code/Koha/" );
use Data::Dumper;

use Koha::REST::Response qw(format_response format_error response_boolean);
use C4::Reserves;
use C4::Circulation;
use C4::Biblio;
use C4::Items;
use C4::Branch;
use C4::Members;
use YAML;
use File::Basename;
use DateTime;

sub setup {
    my $self = shift;
    $self->run_modes(
        get_holds_byid => 'rm_get_holds_byid',
        get_holds => 'rm_get_holds',
		cancel_hold => 'rm_cancel_hold',
        get_issues_byid => 'rm_get_issues_byid',
        get_issues => 'rm_get_issues',
		renew_issue => 'rm_renew_issue',
        get_patron => 'rm_get_patron',
		get_today => 'today',
        get_all => 'all',
		
    );
}

sub rm_get_holds_byid {
    my $self = shift;

    my $borrowernumber = $self->param('borrowernumber');
    return format_response($self, get_holds($borrowernumber));
}

sub rm_get_holds {
    my $self = shift;


    my $user_name = $self->param('user_name');
    my $borrower = C4::Members::GetMember(userid => $user_name);
    my $borrowernumber = $borrower->{borrowernumber};
	return format_response($self, get_holds($borrowernumber));
}


# return current holds of a koha patron
sub get_holds {
    my ($borrowernumber) = @_;
    return [] unless ($borrowernumber);

    my $response = [];
    my @holds = C4::Reserves::GetReservesFromBorrowernumber($borrowernumber);
    foreach my $hold (@holds) {
        my (undef, $biblio) = C4::Biblio::GetBiblio($hold->{biblionumber});
        my $item = C4::Items::GetItem($hold->{itemnumber});
        push @$response, {
            hold_id => $hold->{reserve_id},
            rank => $hold->{priority},
            reservedate => $hold->{reservedate},
            biblionumber => $hold->{biblionumber},
            branchcode => $hold->{branchcode},
            itemnumber => $hold->{itemnumber},
            title => $biblio ? $biblio->{title} : '',
            barcode => $item ? $item->{barcode} : '',
            itemcallnumber => $item ? $item->{itemcallnumber} : '',
            branchname => C4::Branch::GetBranchName($hold->{branchcode}),
            cancellationdate => $hold->{cancellationdate},
            found => $hold->{found},
			hold => $hold,
        };
    }

    return $response;
}



# cancels a patrons hold. Must be given the item number as a param.
sub rm_cancel_hold {

   	my $self = shift;
	my $borrowernumber = $self->param('borrowernumber');
	my $user_name = $self->param('user_name');
	
	my $itemnumber = $self->param('itemnumber');
	my $biblionumber = $self->param('biblionumber');
	my $borrower;
	if ( $borrowernumber) { 
	 $borrower = C4::Members::GetMemberDetails( $borrowernumber );
	} else {    
     $borrower = C4::Members::GetMember(userid => $user_name);
     $borrowernumber = $borrower->{borrowernumber};
	}

    # Get the borrower or return an error code
    return format_error( $self, '404', ['Patron Not Found'] ) unless $$borrower{borrowernumber};

    # Get the item or return an error code
	if ( $biblionumber ) { 
		my $biblio = C4::Biblio::GetBiblio($biblionumber);
		return  format_error($self, '404', ["Biblio $biblionumber Record Not Found"]) unless $$biblio{biblionumber};
	} else  {
    	my $item = C4::Items::GetItem( $itemnumber );
    	return format_response($self, '404', ["Item $itemnumber Record Not Found"] ) unless $$item{itemnumber};
	}
    # Get borrower's reserves
    my @reserves = C4::Reserves::GetReservesFromBorrowernumber( $borrowernumber, undef );
	my @reserveditems;

	if ($biblionumber) {
	  foreach my $reserve (@reserves) {
	        push @reserveditems, $reserve->{'biblionumber'};
		}	
	    
		# if the item was not reserved by the borrower, returns an error code	
		unless ( grep { $_ eq $biblionumber } @reserveditems ) {
			return format_error( $self, '404', ["User $borrowernumber does not currenlt have a hold for biblionumber $biblionumber"]);
		}
		C4::Reserves::CancelReserve(  $biblionumber, undef, $borrowernumber );
	} else {
    	# ...and loop over it to build an array of reserved itemnumbers
    	foreach my $reserve (@reserves) {
        	push @reserveditems, $reserve->{'itemnumber'};
    	}
    	# if the item was not reserved by the borrower, returns an error code
		unless ( grep {$_ eq $itemnumber} @reserveditems) {
    		return format_error( $self, '404', ["User $borrowernumber does not currenlt have a hold for item $itemnumber"]);
		}
    	# Cancel the reserve
    	C4::Reserves::CancelReserve( undef, $itemnumber, $borrowernumber );
	}
    
	return format_response( $self, { canceled => 'true' });
}



sub rm_get_issues_byid {
    my $self = shift;
    my $borrowernumber = $self->param('borrowernumber');

    return format_response($self, get_issues($borrowernumber));
}

sub rm_get_issues {
    my $self = shift;
    my $user_name = $self->param('user_name');
    my $borrower = C4::Members::GetMember(userid => $user_name);
    my $borrowernumber = $borrower->{borrowernumber};

    return format_response($self, get_issues($borrowernumber));
}



# return current issues of a koha patron
sub get_issues {
    my ($borrowernumber) = @_;
    return [] unless ($borrowernumber);

    my $response = [];
    my $issues = C4::Members::GetPendingIssues($borrowernumber);
    if ($issues) {
        foreach my $issue (@$issues) {
            my $itemnumber = $issue->{itemnumber};
            my ($renewable, $error) = C4::Circulation::CanBookBeRenewed(
                $borrowernumber, $itemnumber);

            # Community master version returns DateTime objects but older
            # versions return dates as ISO formatted strings.
            my $date_due = (ref $issue->{date_due} eq "DateTime")
                ? $issue->{date_due}->datetime : $issue->{date_due};
            my $issuedate = (ref $issue->{issuedate} eq "DateTime")
                ? $issue->{issuedate}->datetime : $issue->{issuedate};

            my $item = C4::Items::GetItem($itemnumber);

            my $r = {
                borrowernumber => $issue->{borrowernumber},
                branchcode => $issue->{branchcode},
                itemnumber => $issue->{itemnumber},
                date_due => $date_due,
                issuedate => $issuedate,
                biblionumber => $issue->{biblionumber},
                title => $issue->{title},
                barcode => $issue->{barcode},
                renewable => response_boolean($renewable),
                itemcallnumber => $item->{itemcallnumber},
            };
            if ( (not $renewable) and $error) {
                $r->{reasons_not_renewable} = $error;
            }

            push @$response, $r;
        };
    }

    return $response;
}


# renews a patrons issues
sub rm_renew_issue {


   	my $self = shift;
	my $itemnumber = $self->param('itemnumber');
	my $borrowernumber = $self->param('borrowernumber');
	
  	my $user_name = $self->param('user_name');
	my $borrower;
	if ( $borrowernumber) { 
	 $borrower = C4::Members::GetMemberDetails( $borrowernumber );
	} else {    
     $borrower = C4::Members::GetMember(userid => $user_name);
     $borrowernumber = $borrower->{borrowernumber};
	}
    # Get borrower infos or return an error code
    return format_error($self, '404',  [ "Patron Not Found" ] ) unless $$borrower{borrowernumber};


    # Get the item, or return an error code
    my $item = C4::Items::GetItem( $itemnumber );
    return format_error( $self, '404', ["Record $itemnumber Not Found" ]) unless $$item{itemnumber};
    # Add renewal if possible
    my @renewal = C4::Circulation::CanBookBeRenewed( $borrowernumber, $itemnumber );
    if ( $renewal[0] ) { C4::Circulation::AddRenewal( $borrowernumber, $itemnumber ); }

    my $issue = C4::Circulation::GetItemIssue($itemnumber);
	
	if ( $renewal[0] ) {
        my $out;
	   	$out->{'renewals'} = $issue->{'renewals'};
	    $out->{'date_due'}   = $issue->{'date_due'}->strftime('%Y-%m-%d %H:%S');
	    $out->{'success'}  = $renewal[0];
	   	return format_response($self, $out);
	 		
	} else {
		return format_error( $self, "412", [ $renewal[1] ] );
	}
    # Hashref building
}

# get patron information based on IDs passed in. 
sub rm_get_patron {
	my $self = shift;
	my $conf_path = dirname($ENV{KOHA_CONF});
    my $conf = YAML::LoadFile("$conf_path/rest/config.yaml");

	my $borrowernumber = $self->param('borrowernumber');
  	my $user_name = $self->param('user_name');
	my $borrowers;
   
	if ($user_name) {
		 my $borrower = C4::Members::GetMember(userid => $user_name);
	     $borrowernumber = $borrower->{borrowernumber};
	}
	
	$borrowers = Search({ "borrowernumber" => $borrowernumber}, undef, undef, $conf->{borrowerfields} );
	
	foreach my $patron (@$borrowers) {
        my $attributes = C4::Members::Attributes::GetBorrowerAttributes($patron->{borrowernumber});
        $patron->{attributes} = $attributes;
    }

    return format_response($self, $borrowers);
}
	

sub today {
    my $self = shift;
    # read the config file, we will use the borrowerfields filter if they exist
    my $conf_path = dirname($ENV{KOHA_CONF});
    my $conf = YAML::LoadFile("$conf_path/rest/config.yaml");

    my $today_patrons;
    if ($conf->{borrowerfields} ) {
        $today_patrons = C4::Members::Search({'dateenrolled'=>C4::Dates->today('iso') }, undef, undef, $conf->{borrowerfields}  );
    } else {
        $today_patrons = C4::Members::Search({'dateenrolled'=>C4::Dates->today('iso') } );
    }
    foreach my $patron (@$today_patrons) {
        my $attributes = C4::Members::Attributes::GetBorrowerAttributes($patron->{borrowernumber});
        $patron->{attributes} = $attributes;
    }

    return format_response($self, $today_patrons);
}

sub all {
    my $self = shift;
    # read the config file, we will use the borrowerfields filter if they exist
    my $conf_path = dirname($ENV{KOHA_CONF});
    my $conf = YAML::LoadFile("$conf_path/rest/config.yaml");



    my $all_patrons;
    if ($conf->{borrowerfields} ) {
        $all_patrons = C4::Members::Search({}, undef, undef, $conf->{borrowerfields}  );
    } else {
        $all_patrons = C4::Members::Search({} );
    }

    foreach my $patron (@$all_patrons) {
        my $attributes = C4::Members::Attributes::GetBorrowerAttributes($patron->{borrowernumber});
        $patron->{attributes} = $attributes;
    }
    
    return format_response($self, $all_patrons);
}

1;
