use 5.012;

use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name        => 'Bio::Galaxy::Toolkit',
    dist_version       => 0.002,
    dist_abstract      => 'Toolkit for managing production Galaxy server instances',
    license            => 'GPL_3',
    dist_author        => q{Jeremy Volkening <jdv@base2bio.com>},
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Test::More'     => 0,
        'File::ShareDir' => 0,
    },
    requires => {
        'Bio::Galaxy::API' => 0,
        'Email::Valid'     => 0,
        'File::ShareDir'   => 0,
        'IO::Socket::SSL'  => 0,
        'Net::SMTP'        => 0,
        'Net::Domain'      => 0,
        'App::Cmd'         => 0,
        'YAML::Tiny'       => 0,
    },
    meta_merge => {
        resources => {
            repository => 'https://github.com/jvolkening/galaxy_toolkit'
        }
    },
    add_to_cleanup => [ 'Bio::Galaxy::Toolkit-*' ],
    create_license => 1,
    share_dir => 'share',
);
$builder->create_build_script;
