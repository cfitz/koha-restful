package Koha::REST::Auth;

use base 'CGI::Application';
use Modern::Perl;

use Koha::REST::Response qw(format_response response_boolean format_error);
use C4::Auth;
use C4::Members;
use Data::Dumper;

sub setup {
    my $self = shift;
    $self->run_modes(
		authenticate_patron => 'rm_authenticate_patron',
        put_password => 'rm_put_password',
        forbidden    => 'rm_forbidden',
    );
}


=head2 rm_authenicate_patron

Authenticates a user's login credentials and returns the identifier for 
the patron.

Parameters:

  - username (Required)
	user's login identifier
  - password (Required)
	user's password

=cut

sub rm_authenticate_patron {
    my $self = shift;
    my $q = $self->query();
	

    # Check if borrower exists, using a C4::Auth function...
    if( C4::Auth::checkpw( C4::Context->dbh, $q->param('user_name'), $q->param('password') ) ) {
        # Get the borrower
	    my $borrower = C4::Members::GetMember( userid => $q->param('user_name') );


	    # Build the hashref
	    my $patron->{'id'} = $borrower->{'borrowernumber'};

	    # ... and return his ID
		return format_response( $self,  $patron );
    }

	return format_error( $self, "401", ["Invalid username and/or password. "]) ;
   
}



# Updates the password of a koha user 
sub rm_put_password {
    my $self = shift;
    my $q = $self->query;
    
	my $login = $q->param('user_name');
	my $newpassword = $q->param('new_password');

    my $response;
    my $result = 0;

    # Find the borrowernumber matching the opac login (userid)
    my $borrower = C4::Members::GetMember(userid => $login);
    if ($borrower) {
		# prove does not like this and I'm not sure why it's here.
       # warn $borrower->{'borrowernumber'}; 

        # Changing the password
        $result = C4::Members::ModMember(borrowernumber => $borrower->{'borrowernumber'}, password => $newpassword);
    }

    push @$response, {
        success => $result
    };
    return format_response($self, $response);
}

# Returns a 403 Forbidden error.
sub rm_forbidden {
    my $self = shift;
    my $response = ["Forbidden. $ENV{'REMOTE_ADDR'} is not allowed to use this service. Are you sure configuration variable 'authorizedips' is correctly configured?"];
    return format_error($self, '403', $response);
}


1;
