#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 64;
use Test::MockModule;
use Test::WWW::Mechanize::CGIApp;
use Data::Dumper;

use Koha::REST::User;
use DateTime::Format::DateParse;
use JSON;

my $c4_items_module = new Test::MockModule('C4::Items');
my $c4_biblio_module = new Test::MockModule('C4::Biblio');
my $c4_branch_module = new Test::MockModule('C4::Branch');
my $c4_members_module = new Test::MockModule('C4::Members');
my $c4_reserves_module = new Test::MockModule('C4::Reserves');
my $c4_circulation_module = new Test::MockModule('C4::Circulation');

$c4_items_module->mock('GetItem', \&mock_c4_items_GetItem);
$c4_biblio_module->mock('GetBiblio', \&mock_c4_biblio_GetBiblio);
$c4_branch_module->mock('GetBranchName', \&mock_c4_branch_GetBranchName);
$c4_members_module->mock('GetMember', \&mock_c4_members_GetMember);
$c4_members_module->mock('GetPendingIssues',
    \&mock_c4_members_GetPendingIssues);
$c4_reserves_module->mock('GetReservesFromBorrowernumber',
    \&mock_c4_reserves_GetReservesFromBorrowernumber);
$c4_reserves_module->mock('CancelReserves', 
	\&mock_c4_reserves_GetReservesFromBorrowernumber);
$c4_circulation_module->mock("AddRenewal", \&mock_c4_circulation_AddRenewal);
$c4_circulation_module->mock('CanBookBeRenewed',
    \&mock_c4_circulation_CanBookBeRenewed);
$c4_circulation_module->mock('GetItemIssue',
	    \&mock_c4_circulation_GetItemIssue);
my (%items_by_itemnumber, %branchnames_by_branchcode, %borrowers_by_username,
    %biblios_by_biblionumber, %issues_by_borrowernumber,
    %reserves_by_borrowernumber, %is_item_renewable_by_borrowernumber, %item_renewal);


# Tests

my $mech = Test::WWW::Mechanize::CGIApp->new;
$mech->app('Koha::REST::Dispatch');

my $path; 
my $output;
## /user/:user_name
## GET patron information
$path = "/user/:user_name";

$mech -> get_ok('/user/user1');
$output = from_json($mech->response->content);
is(ref $output, 'ARRAY', "/user/user1 response is an array of size ".(scalar @$output));

## /user/byid/1
$path = "/user/byid/1";
$mech -> get_ok('/user/byid/1');
$output = from_json($mech->response->content);
is(ref $output, 'ARRAY', "/user/byid/1 response is an array of size ".(scalar @$output));

## /user/:user_name/holds
## GET patron's holds.
$path = "/user/:user_name/holds";

$mech->get_ok('/user/user1/holds');
$output = from_json($mech->response->content);
is(ref $output, 'ARRAY', "$path response is an array");
is(scalar @$output, 2, "$path response contains the good number of holds");
foreach my $key (qw(hold_id rank reservedate biblionumber branchcode itemnumber
    title barcode branchname cancellationdate found))
{
    ok(exists $output->[0]->{$key}, "$path first hold contain key '$key'");
    ok(exists $output->[1]->{$key}, "$path second hold contain key '$key'");
}

## DELETE PATRONS HOLDS
$path = "/user/:user_name/holds/biblio/:biblionumber";
$mech->delete('/user/user1/holds/biblio/1');
$output = from_json($mech->response->content);
is( $output->{"code"}, "Canceled", "$path response shows deletes teh biblio hold");
is( $mech->status, 200, "DELETE the hold is OK" );

$path = "/user/:user_name/holds/item/:itemonumber";
$mech->delete('/user/user1/holds/item/1');
$output = from_json($mech->response->content);
is( $output->{"code"}, "Canceled", "$path response contains the good number of holds");
is( $mech->status, 200, "DELETE $path" );

## /user/:user_name/issues
## GET patron's issues
$path = "/user/:user_name/issues";

$mech->get_ok('/user/user1/issues');
$output = from_json($mech->response->content);
is(ref $output, 'ARRAY', "$path response is an array");
is(scalar @$output, 2, "$path response contains the good number of issues");
foreach my $key (qw(borrowernumber branchcode itemnumber date_due issuedate
    biblionumber title barcode renewable))
{
    ok(exists $output->[0]->{$key}, "$path first hold contain key '$key'");
    ok(exists $output->[1]->{$key}, "$path second hold contain key '$key'");
}
foreach my $i (0,1) {
    if ($output->[$i]->{renewable}) {
        ok(not (exists $output->[$i]->{reasons_not_renewable}),
            "$path 'reasons_not_renewable' key is not present if 'renewable' is true");
    } else {
        ok(exists $output->[$i]->{reasons_not_renewable},
            "$path 'reasons_not_renewable' key is present if 'renewable' is false");
    }
}

## RENEW ISSUES
$path = "/user/:user_name/issue/:itemnumber"; 
$mech->put("/user/user1/issue/1");
$output = from_json($mech->response->content);
is( $output->{"success"}, "1", "$path response shows deletes teh biblio hold ");
is( $mech->status, 200, "DELETE the hold is OK" );

$mech->put("/user/user1/issue/2");
$output = from_json($mech->response->content);
is( @$output[0], "on_reserve", "$path response should be an error if we can't renew the issue. ");
is( $mech->status, 412, "DELETE the hold is not allowed" );



## /user/today and /user/all
$mech->get_ok('/user/today');
$output = from_json($mech->response->content);
is(ref $output, 'ARRAY', "/user/today response is an array of size ".(scalar @$output));

$mech->get_ok('/user/all');
$output = from_json($mech->response->content);
is(ref $output, 'ARRAY', "/user/all response is an array of size ".(scalar @$output));

# Mocked subroutines

BEGIN {
    %items_by_itemnumber = (
        1 => {
            holdingbranch => 'B1',
            homebranch => 'B2',
            wthdrawn => 0,
            notforloan => 0,
            onloan => '2000-01-01',
            location => 'ABC',
            itemcallnumber => 'CN0001',
            date_due => '2011-01-01',
            barcode => 'BC0001',
            itemlost => 0,
            damaged => 0,
            stocknumber => 'SN0001',
            itype => 'BOOK',
			itemnumber => '1',
        },
        2 => {
            holdingbranch => 'B3',
            homebranch => 'B2',
            wthdrawn => 1,
            notforloan => 1,
            onloan => '2000-02-02',
            location => 'ABC',
            itemcallnumber => 'CN0001',
            date_due => '2012-02-02',
            barcode => 'BC0002',
            itemlost => 1,
            damaged => 1,
            stocknumber => 'SN0002',
            itype => 'BOOK',
			itemnumber => '2',

        },
    );
}

sub mock_c4_items_GetItem {
    my ($itemnumber) = @_;
	$itemnumber = 2 unless $itemnumber;
    return $items_by_itemnumber{$itemnumber};
}

BEGIN {
    %biblios_by_biblionumber = (
        1 => {
            title => 'Biblio 1',
			biblionumber => "1"
        },
    );
}

sub mock_c4_biblio_GetBiblio {
    my ($biblionumber) = @_;

    return $biblios_by_biblionumber{$biblionumber};
}

BEGIN {
    %branchnames_by_branchcode = (
        B1 => 'Branch 1',
        B2 => 'Branch 2',
        B3 => 'Branch 3',
    );
}

sub mock_c4_branch_GetBranchName {
    my ($branchcode) = @_;

    return $branchnames_by_branchcode{$branchcode};
}

BEGIN {
    %borrowers_by_username = (
        user1 => {
            borrowernumber => 1,
        },
    );
}

sub mock_c4_members_GetMember {
    my %param = @_;

    return {} unless defined $param{userid};

    return $borrowers_by_username{ $param{userid} };
}

BEGIN {
    %issues_by_borrowernumber = (
        1 => [
            {
                borrowernumber => 1,
                branchcode => 'B1',
                itemnumber => 1,
               	date_due => DateTime::Format::DateParse->parse_datetime('2012-01-07'),
			    issuedate => DateTime::Format::DateParse->parse_datetime('2012-01-01'),
                biblionumber => 1,
            },  {
                borrowernumber => 1,
                branchcode => 'B2',
                itemnumber => 2,
               	date_due => DateTime::Format::DateParse->parse_datetime('2012-04-28'),
			    issuedate => DateTime::Format::DateParse->parse_datetime('2012-04-14'),
                biblionumber => 1,
            },
        ],
    );
}

sub mock_c4_members_GetPendingIssues {
    my ($borrowernumber) = @_;
    return $issues_by_borrowernumber{$borrowernumber};
}

sub mock_c4_circulation_GetItemIssue {
	my $borrowernumber = 1;
    return $issues_by_borrowernumber{$borrowernumber}[0];
}


BEGIN {
    %reserves_by_borrowernumber = (
        1 => [
            {
                reserve_id => 1,
                priority => 2,
                reservedate => '2012-05-05',
                biblionumber => 1,
                branchcode => 'B1',
                itemnumber => 1,
                cancellationdate => '',
                found => '',
            },
            {
                reserve_id => 2,
                priority => 0,
                reservedate => '2012-06-06',
                biblionumber => 1,
                branchcode => 'B2',
                itemnumber => 2,
                cancellationdate => '',
                found => 'W',
            },
        ],
    );
}


sub mock_c4_reserves_GetReservesFromBorrowernumber {
    my ($borrowernumber) = @_;

    return @{ $reserves_by_borrowernumber{$borrowernumber} };
}

BEGIN {
    %is_item_renewable_by_borrowernumber = (
        1 => {
            1 => 1,
        },
    );
}


sub mock_c4_circulation_CanBookBeRenewed {
    my ($borrowernumber, $itemnumber) = @_;

    my $reason;
    my $can_renew =
        $is_item_renewable_by_borrowernumber{$borrowernumber}->{$itemnumber}
        ? 1
        : 0;
    if (not $can_renew) {
        $reason = 'on_reserve';
    }

    return ($can_renew, $reason);
}

BEGIN {
	%item_renewal = (
		1 => {
			1 => {
			    
			}
			
		}
	);
}


sub mock_c4_circulation_AddRenewal {
	my ($borrowernumber, $itemnumber) = @_;
    if ($item_renewal{$borrowernumber}->{$itemnumber}){
		return [ "success", undef];
}	else {
		return ( undef, "Error");
	}
}
