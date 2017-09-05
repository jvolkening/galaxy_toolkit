use 5.012;

use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name        => 'galaxy_toolkit',
    dist_version       => 0.001,
    dist_abstract      => 'Toolkit for managing Galaxy server',
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
        'Net::SMTP::SSL'   => 0,
        'Net::Domain'      => 0,
        'Getopt::Long'     => 0,
    },
    meta_merge => {
        resources => {
            repository => 'https://github.com/jvolkening/galaxy_toolkit'
        }
    },
    add_to_cleanup => [ 'galaxy_toolkit-*' ],
    create_license => 1,
    share_dir => 'share',
);
$builder->create_build_script;
