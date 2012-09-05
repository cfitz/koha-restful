package Koha::RESTApplication::User;

use base 'CGI::Application';
use Modern::Perl;

use Koha::RESTApplication::Response qw(format_response response_boolean);
use C4::Reserves;
use C4::Circulation;
use C4::Biblio;
use C4::Items;
use C4::Branch;

sub setup {
    my $self = shift;
    $self->run_modes(
        get_holds => 'rm_get_holds',
        get_issues => 'rm_get_issues',
    );
}

# return current holds of a koha patron
sub rm_get_holds {
    my $self = shift;
    my $user_name = $self->param('user_name');

    my $borrower = C4::Members::GetMember(userid => $user_name);
    my $borrowernumber = $borrower->{borrowernumber};
    unless ($borrowernumber) {
        return format_response($self, []);
    }

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
            branchname => C4::Branch::GetBranchName($hold->{branchcode}),
            cancellationdate => $hold->{cancellationdate},
            found => $hold->{found},
        };
    }

    return format_response($self, $response);
}

# return current issues of a koha patron
sub rm_get_issues {
    my $self = shift;
    my $user_name = $self->param('user_name');

    my $borrower = C4::Members::GetMember(userid => $user_name);
    my $borrowernumber = $borrower->{borrowernumber};
    unless ($borrowernumber) {
        return format_response($self, []);
    }

    my $response = [];
    my $issues = C4::Members::GetPendingIssues($borrowernumber);
    if ($issues) {
        foreach my $issue (@$issues) {
            my $itemnumber = $issue->{itemnumber};
            my ($renewable, $error) = C4::Circulation::CanBookBeRenewed(
                $borrowernumber, $itemnumber);

            my $r = {
                borrowernumber => $issue->{borrowernumber},
                branchcode => $issue->{branchcode},
                itemnumber => $issue->{itemnumber},
                date_due => $issue->{date_due}->ymd,
                issuedate => $issue->{issuedate}->ymd,
                biblionumber => $issue->{biblionumber},
                title => $issue->{title},
                barcode => $issue->{barcode},
                renewable => response_boolean($renewable),
            };
            if ( (not $renewable) and $error) {
                $r->{reasons_not_renewable} = $error;
            }

            push @$response, $r;
        };
    }

    return format_response($self, $response);
}


1;