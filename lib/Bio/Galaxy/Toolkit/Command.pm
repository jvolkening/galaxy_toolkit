package Bio::Galaxy::Toolkit::Command;

use strict;
use warnings;
use 5.012;

use App::Cmd::Setup -command;

sub usage_desc { "galactk adduser %o <username>" }

sub opt_spec {

    my ($class, $app) = @_;

    return (
        [ "url=s" => "URL of server (including port if needed)",
            {default => 'http://localhost:8080'},
        ],
        $class->options($app),
    );
}

1;
