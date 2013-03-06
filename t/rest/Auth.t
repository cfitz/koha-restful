#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 7;
use Test::MockModule;
use Test::WWW::Mechanize::CGIApp;
use Data::Dumper;

use Koha::REST::Auth;
use DateTime::Format::DateParse;
use JSON;


my $c4_auth_module = new Test::MockModule('C4::Auth');
my $c4_members_module = new Test::MockModule('C4::Members');

$c4_auth_module->mock('checkpw', \&mock_c4_auth_checkpw);
$c4_members_module->mock('GetMember', \&mock_c4_members_GetMember);
$c4_members_module->mock('ModMember', \&mock_c4_members_ModMember);

my (%borrowers_by_username);



my $mech = Test::WWW::Mechanize::CGIApp->new;
$mech->app('Koha::REST::Dispatch');

my $path; 
my $output;

# Authenticate User
$path = "/auth/authenticate_patron";

$mech -> post_ok('/auth/authenticate_patron', { "user_name" => "user1", "password" => "foopassword"});
$output = from_json($mech->response->content);
is(ref $output, 'HASH', "$path response is a hash");
ok(exists $output->{id}, "$path response contains key 'id'");


$mech -> post('/auth/authenticate_patron', { "user_name" => "user1", "password" => "barpassword"});
$output = from_json($mech->response->content);
is( $mech->status, 401, "Not allow if the password is not correct" );

$mech -> post('/auth/authenticate_patron', { "user_name" => "jimmy", "password" => "barpassword"});
$output = from_json($mech->response->content);
is( $mech->status, 401, "Again Not allow if the password is not correct" );

# Update PAssword
# So I guess this just changes the password on demand, no checks or nothing...ok.
# Not going to spend much time on this, since we can remove it.
$path = "/auth/change_password";

$mech -> put_ok('/auth/change_password', { user_name => "user2", new_password => "foopassword"});
is( $mech->status, 200, "PUT $path changed password" );

## MOCKS ##

BEGIN {
    %borrowers_by_username = (
        user1 => {
			borrowernumber => "1",
            password => "foopassword",
        },
    );
}


sub mock_c4_auth_checkpw { 
    my ( $context, $user_name, $password) = @_;
	my $user = $borrowers_by_username{ $user_name };
	if ($user && $user->{password}  eq $password) {
		return 1;
	} else { return 0; }
}


sub mock_c4_members_GetMember {
    my %param = @_;
    return {} unless defined $param{userid};
    return $borrowers_by_username{ $param{userid} };
}

# should jsut be true. don't need to test what happens in the database 
sub mock_c4_members_ModMember { return 1 }
