#!/usr/bin/env genome-perl

use strict;
use warnings;

use above "Genome";
use Test::More; 
use File::Compare;
use File::Temp;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}
else {
    plan tests => 18;
}

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use_ok( 'Genome::Model::Tools::DetectVariants2::Filter::TigraValidation');

my $test_input_dir  = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Tools-DetectVariants2-Filter-TigraValidation/';
my $normal_bam  = $test_input_dir . 'normal.bam';
my $tumor_bam   = $test_input_dir . 'tumor.bam';
my $sv_file     = $test_input_dir . 'svs.hq';

my $tmp_base = File::Temp::tempdir(
    'Genome-Model-Tools-DetectVariants2-Filter-TigraValidation-XXXXX', 
    DIR     => "$ENV{GENOME_TEST_TEMP}", 
    CLEANUP => 1,
);

ok(-d $tmp_base, "temp output directory made at $tmp_base");
my $tmp_dir = $tmp_base . '/filter';

my $refbuild_id = 101947881;

my $detector_result = Genome::Model::Tools::DetectVariants2::Result->__define__(
    output_dir => $test_input_dir,
    detector_name => 'test',
    detector_params => '',
    detector_version => 'awesome',
    aligned_reads => $normal_bam,
    control_aligned_reads => $tumor_bam,
    reference_build_id => $refbuild_id,
);
$detector_result->lookup_hash($detector_result->calculate_lookup_hash());

my $sv_valid = Genome::Model::Tools::DetectVariants2::Filter::TigraValidation->create(
    previous_result_id => $detector_result->id,
    output_directory => $tmp_dir,
    specify_chr => 18,
);

ok($sv_valid, 'created TigraValidation object');
ok($sv_valid->execute(), 'executed TigraValidation object OK');

my @test_file_names = qw(svs.out svs.out.normal svs.out.tumor breakpoint_seq.normal.fa breakpoint_seq.tumor.fa cm_aln.out.normal cm_aln.out.tumor);
for my $file_name (@test_file_names) {
    ok(-s $tmp_dir."/$file_name", "output file $file_name generated ok"); 
    is(compare($tmp_dir."/$file_name", $test_input_dir."/$file_name"), 0, "output $file_name matches as expected");
}

done_testing();
