package Bio::Galaxy::Toolkit::Command::adduser;

use strict;
use warnings;
use 5.012;

use Bio::Galaxy::Toolkit -command;

use Email::Valid;
use Net::SMTP::SSL;
use Net::Domain qw/hostfqdn/;
use File::ShareDir qw/dist_file/;
use YAML::Tiny;

use parent 'Bio::Galaxy::Toolkit::Command';

sub options {

    my ($app) = @_;

    return (
        [ "name=s"     => "Full name"                                 ],
        [ "user=s"     => "User name"                                 ],
        [ "email=s"    => "Email address"                             ],
        [ "org=s"      => "Organization to use in notification email" ],
        [ "pw_len=i"   => "Length of temporary password"              ],
        [ "group=s@"   => "Group(s) to which to add user"             ],
        [ "cc=s@"      => "Email address to copy notification to"     ],
        [ "template=s" => "Path to email template to use"             ],
        [ "create_lib" => "Create a user-specific library"            ],
        [ "config=s"   => "Path to configuration file"                ],
    );

}

sub execute {

    my ($self, $opts, $args) = @_;

    my $url = $opts->{url} // 'http://localhost:8080';

    # read in configuration, if present
    my $fn_cfg = $opts->{config} // "$ENV{HOME}/.galactk.yml";
    my $cfg = {};
    if (-e $fn_cfg) {
        $cfg = YAML::Tiny->read($fn_cfg)->[0];
    }

    # validation
    die "missing name or email\n"
        if (! defined $opts->{name} || ! defined $opts->{email});

    my $name  = $opts->{name};

    my $email = $opts->{email};
    die "Bad email\n"
        if (! Email::Valid->address($email));

    my $username = $opts->{user} 
        // lc $opts->{name} 
        // die "No user name or full name specified";
    $username = lc $opts->{name};
    $username =~ s/\s+/_/g;
    pos($username) = 0;
    $username =~ s/[^a-z0-9\_\-]/-/g;

    my $pw_len = $opts->{pw_len} // 8;

    my @groups = $opts->{group}
        ? @{ $opts->{group} }
        : ();

    my $template = $opts->{template};

    if (! defined $template) {
        $template = dist_file('Bio-Galaxy-Toolkit' => 'new_user.template');
    }

    die "missing or unreadable mail template\n"
        if (! -r $template);

    my $pw = random_pw( $pw_len );

    my $org = $opts->{org};

    my @cc = $opts->{cc}
        ? @{ $opts->{cc} }
        : ();

    my $usr = create_galaxy_user(
        $username,
        $email,
        $name,
        $pw,
        $url,
        $opts->{create_lib},
        @groups,
    );
    my $msg = generate_email_text(
        $template, $name, $username, $email, $org, $pw
    );
    send_mail($cfg, $msg, $email, @cc);

}

sub add_groups {

    my ($usr, @groups) = @_;

}

sub create_galaxy_user {

    my (
        $username,
        $email,
        $name,
        $pw,
        $url,
        $create_lib,
        @groups,
    ) = @_;

    my $check_secure = $url =~ /^http:\/\/localhost(?::\d+)?/
        ? 0
        : 1;

    my $ua = Bio::Galaxy::API->new(
        url => $url,
        check_secure => $check_secure,
    );

    my $usr = $ua->new_user(
        user     => $username,
        email    => $email,
        password => $pw,
    );

    if (defined $usr) {
        say "Successfully created Galaxy user";
    }
    else {
        say "Error creating Galaxy user";
        exit;
    }

    my @found = $ua->groups;

    GROUP:
    for my $grp (@groups) {

        my @g = grep { $_->name eq $grp  } @found;

        if (scalar @g != 1) {
            warn "WARNING: Failed to locate unique group named $grp\n";
            next GROUP;
        }
            
        my $success = $g[0]->add_user(user => $usr);
        if (! $success) {
            warn "WARNING: Failed to add user to group $grp\n";
            next GROUP;
        }

        warn "Successfully added user to group $grp\n";

    }

    # create personal library if requested
    if ($create_lib) {

        my $lib = $ua->new_library(
            name => $email,
            description => "Personal library for $name",
        );
        if (! defined $lib) {
            warn "Personal library creation failed: $!\n";
            return;
        }

        # CRITICAL: library permissions are set using role ID, not user ID. To
        # do this we must obtain the ID of the private role associated with a
        # user. User and role IDs can (and often do) collide, so failure to
        # use the correct ID can (and will) cause incorrect permissions to be
        # set.
        my $role = $usr->private_role;
        $lib->set_permissions(
            access_ids => ["$role"],
            manage_ids => ["$role"],
            add_ids    => ["$role"],
            modify_ids => [],
        ) or die "failed to set permissions: $!";

        say "Successfully created user library";

    } 

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

    my $smtp = Net::SMTP::SSL->new(
        $host,
        Port => $port,
    );
    if (! $smtp) {
        die "Error starting SMTP session: $@\n";
    }

    # Authenticate if using smarthost
    if (defined $cfg->{smarthost}) {
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

sub random_pw {

    my ($len) = @_;

    my @pw_chars = (
        'A'..'Z',
        'a'..'z',
        0..9,
        qw/! +/,
    );

    return join '', map {
        $pw_chars[ int(rand(scalar(@pw_chars))) ]
    } 1..$len;
        
}

sub generate_email_text {

    my ($template, $name, $user, $email, $org, $pw) = @_;

    my $msg;

    open my $tpl, '<', $template
        or die "Error opening template file: $!\n";

    while (my $line = <$tpl>) {
        for my $token (
            [ 'NAME'  => $name  ],
            [ 'USER'  => $user  ],
            [ 'EMAIL' => $email ],
            [ 'ORG'   => $org   ],
            [ 'PW'    => $pw    ],
        ) {
            $line =~ s/<<<<$token->[0]>>>>/$token->[1]/;
        }
        $msg .= $line;
    }

    return $msg;

}

1;
