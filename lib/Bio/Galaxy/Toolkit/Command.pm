package Bio::Galaxy::Toolkit::Command;

use strict;
use warnings;
use 5.012;

use App::Cmd::Setup -command;

use Net::Domain qw/hostfqdn/;
use Net::SMTP;

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

sub send_mail {

    my ($cfg, $msg, $email, @cc) = @_;

    my $sender = $cfg->{smarthost}->{from}
        // $ENV{USER} . '@' . hostfqdn();

    my $replyto = $cfg->{smarthost}->{reply_to}
        // $sender;

    my $host = $cfg->{smarthost}->{host}
        // 'localhost';

    my $port = $cfg->{smarthost}->{port}
        // 22;

    my $hello = $cfg->{smarthost}->{hello}
        // hostfqdn();

    my $use_ssl = $cfg->{smarthost}->{ssl}
        // 0;

    my $smtp = Net::SMTP->new(
        $host,
        Port  => $port,
        Hello => $hello,
        SSL   => $use_ssl,
    );
    if (! $smtp) {
        die "Error starting SMTP session: $@\n";
    }

    # Authenticate if given smarthost user/pass
    if (defined $cfg->{smarthost}->{user}) {
        $smtp->auth(
            $cfg->{smarthost}->{user},
            $cfg->{smarthost}->{pass}
        ) or die "Authentication failed!\n";
    }

    $smtp->mail($sender);
    $smtp->to($email);
    $smtp->cc(@cc);

    $smtp->data();
    $smtp->datasend("To: $email\n");
    $smtp->datasend("From: $sender\n");
    $smtp->datasend("Reply-To: $replyto\n");
    $smtp->datasend("Subject: Galaxy account creation\n");
    $smtp->datasend("\n");
    $smtp->datasend($msg);
    $smtp->dataend()
        or die "Failed to send email: $!";

    $smtp->quit();

    say "Successfully sent mail notification";
    
    return;

}


1;
