#!/usr/bin/env genome-perl

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Compare;
use Genome::Test::Factory::SoftwareResult::User;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    }
};

use_ok( 'Genome::Model::Tools::DetectVariants2::Combine::UnionSnv');

my $test_data_dir  = Genome::Config::get('test_inputs') . '/Genome-Model-Tools-DetectVariants2-Combine-UnionSnv';
is(-d $test_data_dir, 1, 'test_data_dir exists') || die;

my $expected_output = $test_data_dir."/expected";
is(-d $expected_output, 1, 'expected_output exists') || die;

# FIXME Swap this for a test constructed reference build.
my $reference_build = Genome::Model::Build->get(101947881);
ok($reference_build, 'got reference_build');

my $result_users = Genome::Test::Factory::SoftwareResult::User->setup_user_hash(
    reference_sequence_build => $reference_build,
);

my $aligned_reads         = join('/', $test_data_dir, 'flank_tumor_sorted.bam');
my $control_aligned_reads = join('/', $test_data_dir, 'flank_normal_sorted.bam');

my $vcf_version = Genome::Model::Tools::Vcf->get_vcf_version;
my $detector_name_a = 'Genome::Model::Tools::DetectVariants2::Samtools';
my $detector_a_vcf_directory = Genome::Config::get('test_inputs') . "/Genome-Model-Tools-DetectVariants2-Combine-UnionSnv/samtools_vcf_result";
my $detector_b_vcf_directory = Genome::Config::get('test_inputs') . "/Genome-Model-Tools-DetectVariants2-Combine-UnionSnv/varscan_vcf_result";
my $detector_version_a = 'awesome';
my $output_dir_a = join('/', $test_data_dir, 'samtools-r599-');
my $detector_a = Genome::Model::Tools::DetectVariants2::Result->__define__(
    output_dir            => $output_dir_a,
    reference_build       => $reference_build,
    detector_name         => $detector_name_a,
    detector_version      => $detector_version_a,
    detector_params       => '',
    aligned_reads         => $aligned_reads,
    control_aligned_reads => $control_aligned_reads,
);
$detector_a->lookup_hash($detector_a->calculate_lookup_hash());

my $detector_a_vcf_result = Genome::Model::Tools::DetectVariants2::Result::Vcf::Detector->__define__(
    input => $detector_a,
    output_dir => $detector_a_vcf_directory,
    aligned_reads_sample => "TEST",
    control_aligned_reads_sample => "TEST-normal",
    vcf_version => $vcf_version,
);

$detector_a_vcf_result->lookup_hash($detector_a_vcf_result->calculate_lookup_hash());
$detector_a->add_user(user => $detector_a_vcf_result, label => 'uses');

isa_ok($detector_a, 'Genome::Model::Tools::DetectVariants2::Result', 'detector_a');

my $detector_name_b    = 'Genome::Model::Tools::DetectVariants2::VarscanSomatic';
my $detector_version_b = 'awesome';
my $output_dir_b = join('/', $test_data_dir, 'varscan-somatic-2.2.4-');
my $detector_b = Genome::Model::Tools::DetectVariants2::Result->__define__(
    output_dir            => $output_dir_b,
    reference_build       => $reference_build,
    detector_name         => $detector_name_b,
    detector_version      => $detector_version_b,
    detector_params       => '',
    aligned_reads         => $aligned_reads,
    control_aligned_reads => $control_aligned_reads,
);
$detector_b->lookup_hash($detector_b->calculate_lookup_hash());

my $detector_b_vcf_result = Genome::Model::Tools::DetectVariants2::Result::Vcf::Detector->__define__(
    input => $detector_b,
    output_dir => $detector_b_vcf_directory,
    aligned_reads_sample => "TEST",
    control_aligned_reads_sample => "TEST-normal",
    vcf_version => $vcf_version,
);
$detector_b_vcf_result->lookup_hash($detector_b_vcf_result->calculate_lookup_hash());

$detector_b->add_user(user => $detector_b_vcf_result, label => 'uses');

isa_ok($detector_b, 'Genome::Model::Tools::DetectVariants2::Result', 'detector_b');

my $test_output_dir = File::Temp::tempdir('Genome-Model-Tools-DetectVariants2-Combine-UnionSnv-XXXXX', CLEANUP => 1, TMPDIR => 1);
my $output_symlink  = join('/', $test_output_dir, 'union-snv');
my $union_snv_object = Genome::Model::Tools::DetectVariants2::Combine::UnionSnv->create(
    input_a_id       => $detector_a->id,
    input_b_id       => $detector_b->id,
    output_directory => $output_symlink,
    aligned_reads_sample => "TEST",
    control_aligned_reads_sample => "TEST-normal",
    result_users     => $result_users,
);
ok($union_snv_object, 'created UnionSnv object');
ok($union_snv_object->execute(), 'executed UnionSnv object');

my @files = qw| snvs.hq.bed
                snvs.lq.bed |;

for my $file (@files) {
    my $test_output = $output_symlink."/".$file;
    my $expected_output = $expected_output."/".$file;
    is(compare($test_output,$expected_output),0, "Found no difference between test output: ".$test_output." and expected output:".$expected_output);
}

my $combine_vcf_result = $union_snv_object->_vcf_result;

isa_ok($combine_vcf_result, 'Genome::Model::Tools::DetectVariants2::Result::Vcf::Combine', "Combine VCF result was found.");

done_testing();
