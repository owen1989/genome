#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

use above "Genome";
use File::Temp;
use Test::More;
use Genome::Utility::Vcf "diff_vcf_file_vs_file";

my $cmd_class = 'Genome::Model::Tools::Vcf::CreateCrossSampleVcf';
my $sr_class = $cmd_class.'Result';

use_ok($cmd_class);
use_ok($sr_class);

my $test_data_directory = join("/", $ENV{GENOME_TEST_INPUTS},
        "Genome-Model-Tools-Vcf-CreateCrossSampleVcf");
diag("Test data located at: $test_data_directory");
my $region_file = join("/", $test_data_directory, "input",
        "2477F2D7AC5111E1874EF15E46F0A7A3_short.bed");
my $region_file_content_hash = Genome::Sys->md5sum($region_file);
my $expected_result = join("/", $test_data_directory, "expected_6",
        "snvs.merged.vcf.gz");

my $joinx_version = "1.6";
my @input_builds = map{ Genome::Model::Build->get($_)}
        (132916834, 132916881, 132916907);

my $output_directory = Genome::Sys->create_temp_directory();

#construct the FeatureList needed
my $roi_list = Genome::FeatureList->create(
        name                => 'test feature-list',
        format              => 'multi-tracked',
        content_type        => 'targeted',
        file_path           => $region_file,
        file_content_hash   => $region_file_content_hash,
        reference_id        => 108563338,
);

sub test_cmd {
    my $name = shift;
    my %params = @_;
    my $this_output_directory = join("/", $output_directory, $name);
    Genome::Sys->create_directory($this_output_directory);
    $params{output_directory} = $this_output_directory;

    my $cmd = $cmd_class->create(%params);
    ok($cmd, "$name: created CreateCrossSampleVcf object");

    ok($cmd->execute(), "$name: executed CreateCrossSampleVcf");
    my $result = $cmd->final_result;
    ok(-s $result, "$name: result of CreateCrossSampleVcf, snvs.merged.vcf.gz exists");

    my %sr_params = %params;
    delete $sr_params{'output_directory'};
    my $sr = $sr_class->get_with_lock(%sr_params);
    ok($sr, "$name: found software result for test1");
    is($sr, $cmd->software_result, '$name: found software result via cmd for test1');

    my $diff = diff_vcf_file_vs_file($result, $expected_result);
    ok(!$diff, '$name: output matched expected result')
        or diag("diff results:\n" . $diff);
}

my %params = (
        builds => \@input_builds,
        max_files_per_merge => 2,
        variant_type => 'snvs',
        roi_list => $roi_list,
        wingspan => 500,
        allow_multiple_processing_profiles => undef,
        joinx_version => $joinx_version,
);

test_cmd("test_1", %params);
$params{max_files_per_merge} = undef;
test_cmd("test_2", %params);


done_testing();
