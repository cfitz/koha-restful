package Koha::REST::Dispatch;

use C4::Context;
use base 'CGI::Application::Dispatch';

sub dispatch_args {
    return {
        prefix => 'Koha::REST',

        # Each entry in the table below correspond to an application and a run
        # mode. An application is a Perl module in Koha::REST. For
        # example, { app => 'User' } correspond to Koha::REST::User.
        # Run modes are described in corresponding Perl module.
        #
        # Notes for building new paths:
        #   ':variable'  : a required parameter
        #   ':variable?' : an optional parameter
        #   '[method]'   : put at the end of path, tell that we can only use
        #                  this HTTP method to run the corresponding mode.
        #   Optional parameters can be omitted from the path.
        table => [
            'informations[get]'
                => { app => 'Infos', rm => 'informations' },
            'branches[get]'
                => { app => 'Infos', rm => 'branches' },

			# User Information
			'user/byid/:borrowernumber[get]'
                => { app => 'User', rm => 'get_patron' },
            'user/:user_name[get]'
                => { app => 'User', rm => 'get_patron' },
			
			# holds
			# Get holds
        
			'user/byid/:borrowernumber/holds[get]'
	                => { app => 'User', rm => 'get_holds_byid' },
			'user/:user_name/holds[get]'
			        => { app => 'User', rm => 'get_holds' },
    	

			# Delete Holds
			'user/:user_name/holds/biblio/:biblionumber[delete]'
				=> { app => 'User', rm => 'cancel_hold'  },
			'user/byid/:borrowernumber/holds/biblio/:biblionumber[delete]'
				 => { app => 'User', rm => 'cancel_hold'  },
				
			'user/:user_name/holds/item/:itemnumber[delete]'
				=> { app => 'User', rm => 'cancel_hold'  },
			'user/byid/:borrowernumber/holds/item/:itemnumber[delete]'
				 => { app => 'User', rm => 'cancel_hold'  },

			# Issues
			#Get Issues
            'user/byid/:borrowernumber/issues[get]'
                => { app => 'User', rm => 'get_issues_byid' },
			'user/:user_name/issues[get]'
		                => { app => 'User', rm => 'get_issues' },
			
			# Renew Issues
			'user/:user_name/issue/:itemnumber[put]'
				=> { app => 'User', rm => 'renew_issue'  },
			'user/byid/:borrowernumber/issue/:itemnumber[put]'
				 => { app => 'User', rm => 'renew_issue'  },

			# Get Users From Today or Get All Users
            'user/today'
                => { app => 'User', rm => 'get_today' },
            'user/all'
                => { app => 'User', rm => 'get_all' },
           
			# Biblio
			# Get Bilbio Record
			'biblio/:biblionumber[get]'
				=> { app => 'Catalogue', rm => 'get_biblio' },
                
			
			
            'biblio/:biblionumber/items[get]'
                => { app => 'Catalogue', rm => 'get_biblio_items' },
            'biblio/:biblionumber/holdable[get]'
                => { app => 'Catalogue', rm => 'biblio_is_holdable' },
		   'biblio/:biblionumber/hold[get]' 
						=> { app => 'Catalogue', rm => 'biblio_is_holdable' },
		
			'biblio/:biblionumber/hold[post]' 
				=> { app => 'Catalogue', rm => 'biblio_hold' },
		
          
  			'biblio/:biblionumber/items_holdable_status[get]'
                => { app => 'Catalogue', rm => 'get_biblio_items_holdable_status' },    
		
			'item/:itemnumber/holdable[get]'
                => { app => 'Catalogue', rm => 'item_is_holdable' },
			'item/:itemnumber/hold[post]' 
						=> { app => 'Catalogue', rm => 'item_hold' },
						
            'auth/change_password[put]'
                => { app => 'Auth', rm => 'put_password' },
			'auth/authenticate_patron[post]'
		                => { app => 'Auth', rm => 'authenticate_patron' },
        ],
    };
}

1;
