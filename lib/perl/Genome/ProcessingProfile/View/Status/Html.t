#!/usr/bin/env genome-perl

use strict;
use warnings;

use above "Genome";

use Test::More;

use_ok('Genome::ProcessingProfile::View::Status::Html') or die;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

my $pp = Genome::ProcessingProfile::TestPipeline->create(
    name => 'Test Pipeline Test for Testing',
    some_command_name => 'ls',
);
ok($pp, "created processing profile") or die;
my $model = Genome::Model->create(
    processing_profile => $pp,
    subject_name => 'human',
    subject_type => 'species_name',
    user_name => 'apipe',
);
ok($model, 'create model') or die;

my $view_obj = $pp->create_view(
    xsl_root => Genome->base_dir . '/xsl',
    rest_variable => '/cgi-bin/rest.cgi',
    toolkit => 'html',
    perspective => 'status',
); 
ok($view_obj, "created a view") or die;
isa_ok($view_obj, 'Genome::ProcessingProfile::View::Status::Html');

my $html = $view_obj->_generate_content();
ok($html, "view returns HTML");

done_testing();
