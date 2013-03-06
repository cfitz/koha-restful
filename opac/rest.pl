#!/usr/bin/perl

# rest.pl
#
# This script provide a RESTful webservice to interact with Koha.

use Modern::Perl;
use YAML;
use File::Basename;
use CGI::Application::Dispatch;
use List::MoreUtils qw(any);

my $conf_path = dirname($ENV{KOHA_CONF});
my $conf = YAML::LoadFile("$conf_path/rest/config.yaml");
# First of all, let's test if the client IP is allowed to use our service
# If the remote address is not allowed, redirect to 403
my @AuthorizedIPs = $conf->{authorizedips} ? @{ $conf->{authorizedips} } : ();
if ( !@AuthorizedIPs # If no filter set, allow access to no one!
    or not any { $ENV{'REMOTE_ADDR'} eq $_ } @AuthorizedIPs # IP Check
    ) {
    CGI::Application::Dispatch->dispatch(
        debug => 1,
        prefix => 'Koha::REST',
        table => [
            '*' => { app => 'Auth', rm => 'forbidden' },
            '/' => { app => 'Auth', rm => 'forbidden' },
        ],
    );
    exit 0;
}


use Koha::REST::Dispatch;

Koha::REST::Dispatch->dispatch(
    debug => 1,
);

__END__

=head1 NAME

rest.pl

=head1 DESCRIPTION

This script provide a RESTful webservice to interact with Koha.

=head1 SERVICES



=head2 Infos

=head3 GET branches

=over 2

Get the list of branches

Response:

=over 2

a JSON array that contains branches. Each branch is described by a hash with the
following keys:

=over 2

=item * code: internal branch identifier

=item * name: branch name

=back

=back

=back



=head2 User

=head3 GET user/byid/:borrowernumber/holds

=over 2

Get holds of a user, given his id.

Required parameters:

=over 2

=item * borrowernumber: Patron id.

=back

Response:

=over 2

a JSON array that contains holds. Each hold is described by a hash with the
following keys:

=over 2

=item * hold_id: internal hold identifier.

=item * rank: position of the patron in reserve queue.

=item * reservedate: date of reservation.

=item * biblionumber: internal biblio identifier.

=item * title: title of bibliographic record.

=item * branchcode: pickup library code.

=item * branchname: pickup library name.

=item * found: 'W' if item is awaiting for pickup.

=back

If reserve is at item level, there are two additional keys:

=over 2

=item * itemnumber: internal item identifier.

=item * barcode: barcode of item.

=back

=back

=back

=head3 GET user/:user_name/holds

=over 2

Get holds of a user, given his username.

Required parameters:

=over 2

=item * user_name: Patron username.

=back

Response:

=over 2

a JSON array that contains holds. Each hold is described by a hash with the
following keys:

=over 2

=item * hold_id: internal hold identifier.

=item * rank: position of the patron in reserve queue.

=item * reservedate: date of reservation.

=item * biblionumber: internal biblio identifier.

=item * title: title of bibliographic record.

=item * branchcode: pickup library code.

=item * branchname: pickup library name.

=item * found: 'W' if item is awaiting for pickup.

=back

If reserve is at item level, there are two additional keys:

=over 2

=item * itemnumber: internal item identifier.

=item * barcode: barcode of item.

=back

=back

=back


=head3 DELETE user/:user_name/holds/biblio/:biblionumber

=over 2

Delete a user's title hold.

Required paramters:

=over 2

=item * :user_name: Patron username.

=item * :biblionumber: An items biblionumber

=back

Response 

=over 2
	
a HTTP 200 with a  JSON hash that contains a code => "Canceled". Each hold is described by a hash with the
following keys:

=over 2

=item * code: value of Canceled.

=back

=back

=back 


=head3 DELETE user/byid/:borrowernumber/holds/biblio/:biblionumber

=over 2

Delete a user's title hold.

Required paramters:

=over 2

=item * :borrowernumber: Patron borrower number.

=item * :biblionumber: An items biblionumber

=back

Response 

=over 2
	
a HTTP 200 with a  JSON hash that contains a code => "Canceled". Each hold is described by a hash with the
following keys:

=over 2

=item * code: value of Canceled.

=back

=back

=back




=head3 DELETE user/:user_name/holds/item/:itemnumber

=over 2

Delete a user's item hold.

Required paramters:

=over 2

=item * :user_name: Patron username.

=item * :item: An items itemnumber

=back

Response 

=over 2
	
a HTTP 200 with a  JSON hash that contains a code => "Canceled". Each hold is described by a hash with the
following keys:

=over 2

=item * code: value of Canceled.

=back

=back

=back




=head3 DELETE user/byid/:borrowernumber/holds/item/:itemnumber

=over 2

Delete a user's item hold.

Required paramters:

=over 2

=item * :borrowernumber: Patron borrower number.

=item * :item: An items item

=back

Response 

=over 2
	
a HTTP 200 with a  JSON hash that contains a code => "Canceled". Each hold is described by a hash with the
following keys:

=over 2

=item * code: value of Canceled.

=back

=back

=back



=head3 GET user/byid/:borrowernumber/issues

=over 2

Get issues of a user, given his id.

Required parameters:

=over 2

=item * borrowernumber: Patron id.

=back

Response:

=over 2

a JSON array that contains issues. Each issue is described by a hash with the
following keys:

=over 2

=item * borrowernumber: internal patron identifier.

=item * biblionumber: internal biblio identifier.

=item * title: title of bibliographic record.

=item * itemnumber: internal item identifier.

=item * barcode: barcode of item.

=item * branchcode: pickup library code.

=item * issuedate: date of issue.

=item * date_due: the date the item is due.

=item * renewable: is the issue renewable ? (boolean)

=back

If the issue is not renewable, there is one additional key:

=over 2

=item * reasons_not_renewable: 2 possible values:

=over 2

=item * 'on_reserve': item is on hold.

=item * 'too_many': issue was renewed too many times.

=back

=back

=back

=back

=head3 GET user/:user_name/issues

=over 2

Get issues of a user, given his username.

Required parameters:

=over 2

=item * user_name: Patron username.

=back

Response:

=over 2

a JSON array that contains issues. Each issue is described by a hash with the
following keys:

=over 2

=item * borrowernumber: internal patron identifier.

=item * biblionumber: internal biblio identifier.

=item * title: title of bibliographic record.

=item * itemnumber: internal item identifier.

=item * barcode: barcode of item.

=item * branchcode: pickup library code.

=item * issuedate: date of issue.

=item * date_due: the date the item is due.

=item * renewable: is the issue renewable ? (boolean)

=back

If the issue is not renewable, there is one additional key:

=over 2

=item * reasons_not_renewable: 2 possible values:

=over 2

=item * 'on_reserve': item is on hold.

=item * 'too_many': issue was renewed too many times.

=back

=back

=back

=back



=head3 PUT user/:user_name/issue/:itemnumber

=over 2

Renews a user's issue

Required paramters:

=over 2

=item * :user_name: Patron username.

=item * :itemnumber: An items itemnumber

=back

Response 

=over 2
	
a HTTP 200 with a  JSON hash  Each hold is described by a hash with the
following keys:

=over 2

=item * success: value of 1 to indicate success. Kinda stupid but whatever.

=item * renewals: number of renewals the user has made on the item.

=item * date_due: the revised due date of the item. 

=back

=back

=back

=head3 PUT user/byid/:borrowernumber/issue/:itemnumber

=over 2

Renews a user's issue

Required paramters:

=over 2

=item * :borrowernumber: Patron borrowernumber.

=item * :itemnumber: An items itemnumber

=back

Response 

=over 2
	
a HTTP 200 with a  JSON hash  Each hold is described by a hash with the
following keys:

=over 2

=item * success: value of 1 to indicate success. Kinda stupid but whatever.

=item * renewals: number of renewals the user has made on the item.

=item * date_due: the revised due date of the item. 

=back

=back

=back

=head3 GET user/today

=over 2

Get information about patrons enrolled today

Required parameters:

=over 2

None

=back

Response:

=over 2

a JSON array containing all informations about patrons enrolled today and it's extended attributes

=back

=back

=head3 GET user/all

=over 2

Get information about all patrons

Required parameters:

=over 2

None

=back

Response:

=over 2

a JSON array containing all informations about all patrons, and their extended attributes

Warning, this file will be large !!!

=back

=back





=head2 Biblio


=head3 GET biblio/:biblionumber

=over 2

Get a bibliographic record

Required parameters:

=over 2

=item * biblionumber: internal biblio identifier.

=back

Response:

=over 2

a JSON hash that contains a dump of the bibliographic record. There's a lot so I'm not going to go over all the key values. Sorry. 

=over 2

=back

=back

=back


=head3 GET biblio/:biblionumber/items

=over 2

Get items of a bibliographic record.

Required parameters:

=over 2

=item * biblionumber: internal biblio identifier.

=back

Response:

=over 2

a JSON array that contains items. Each item is described by a hash with the
following keys:

=over 2

=item * itemnumber: internal item identifier.

=item * holdingbranch: holding library code.

=item * holdingbranchname: holding library name.

=item * homebranch: home library code.

=item * homebranchname: home library name.

=item * withdrawn: is the item withdrawn ?

=item * notforloan: is the item not available for loan ?

=item * onloan: date of loan if item is on loan.

=item * location: item location.

=item * itemcallnumber: item call number.

=item * date_due: due date if item is on loan.

=item * barcode: item barcode.

=item * itemlost: is item lost ?

=item * damaged: is item damaged ?

=item * stocknumber: item stocknumber.

=item * itype: item type.

=back

=back

=back

=head3 GET biblio/:biblionumber/holdable

=over 2

Check if a biblio is holdable.

Required parameters:

=over 2

=item * biblionumber: internal biblio identifier.

=back

Optional parameters:

=over 2

=item * borrowernumber: internal patron identifier. It is optional but highly
recommended, as no check is performed without it and a true value is always
returned.

=item * itemnumber: internal item identifier. If given, check is done on item
instead of biblio.

=back

Response:

=over 2

a JSON hash that contains the following keys:

=over 2

=item * is_holdable: is the biblio holdable? (boolean)

=item * reasons: reasons why the biblio can't be reserved, if appropriate.
Actually there is no valid reasons...

=back

=back

=back

=head3 POST biblio/:biblionumber/hold

=over 2

Holds  a biblio is for a user.

Required parameters:

=over 2

=item * biblionumber: internal biblio identifier.

=item * borrowernumber: Patron's borrower number OR

=item * user_name: Patron's user name. Either borrowernumber or user_name must be included. 

=back

Response:

=over 2

a JSON hash that contains the following keys:

=over 2

=item * biblionumber: is the item's biblionumber

=item * title: the item's title

=item * borrowernumber: Just spitting back the borrower's number. 

=item * pickup_location: location that the item will be picked up at. 

=back

=back

=back

=head3 GET biblio/:biblionumber/items_holdable_status

=over 2

Check if items of a bibliographic record are holdable.

Required parameters:

=over 2

=item * biblionumber: internal biblio identifier.

=back

Optional parameters:

=over 2

=item * borrowernumber: Patron borrowernumber. It is optional but highly
recommended. If not given, all items will be marked as not holdable.

=item * user_name: Patron username. Only used to find borrowernumber if this one
is not given.

=back

Response:

=over 2

a JSON hash where keys are itemnumbers. Each element of this hash contain
another hash whose keys are:

=over 2

=item * is_holdable: is the item holdable ? (boolean)

=item * reasons: reasons why the biblio can't be reserved, if appropriate.
Actually there is no valid reasons...

=back

=back

=back









=head2 Item

=head3 GET item/:itemnumber/holdable

=over 2

Check if an item is holdable.

Required parameters:

=over 2

=item * itemnumber: internal item identifier.

=back

Optional parameters:

=over 2

=item * user_name: patron username. It is optional but highly recommended. If
not given, item will be marked as not holdable.

=back

Response:

=over 2

a JSON hash with following keys:

=over 2

=item * is_holdable: is item holdable ? (boolean)

=item * reasons: reasons why the biblio can't be reserved, if appropriate.
Actually there is no valid reasons...

=back

=back

=back

=head3 POST item/:itemnumber/hold

=over 2

Holds  an item is for a user.

Required parameters:

=over 2

=item * itemnumber: internal item identifier.

=item * borrowernumber: Patron's borrower number OR

=item * user_name: Patron's user name. Either borrowernumber or user_name must be included. 

=back

Response:

=over 2

a JSON hash that contains the following keys:

=over 2

=item * biblionumber: is the item's biblionumber

=item * title: the item's title

=item * itemnumber: The item number of the item held. 

=item * borrowernumber: Just spitting back the borrower's number. 

=item * pickup_location: location that the item will be picked up at. 

=back

=back

=back



=head2 Auth

=head3 PUT auth/change_password

=over 2

Change user password.

Required parameters:

=over 2

=item * user_name: patron username.

=item * new_password: wanted password.

=back

Response:

=over 2

a JSON array which contains one hash with the following keys:

=over 2

=item * success: does the operation succeeded ?

=back

=back

=back


=head3 POST auth/authenticate_patron

=over 2

Authenticate a parton to koha. 

Required parameters:

=over 2

=item * user_name: patron username.

=item * password: user's password.

=back

Response:

=over 2

a HTTP 200 and JSON hash which contains the patrons id. Failure will get a HTTP 401.

=over 2

=item * id: The patron's user id. 

=back

=back

=back


=cut
