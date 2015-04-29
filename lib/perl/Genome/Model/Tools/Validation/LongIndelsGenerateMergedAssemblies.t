#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Compare;
use File::Copy qw(copy);

use_ok("Genome::Model::Tools::Validation::LongIndelsGenerateMergedAssemblies");

my $version = 2;
my $base_dir = Genome::Config::get('test_inputs')."/Genome-Model-Tools-Validation-LongIndelsGenerateMergedAssemblies/v$version";
my $temp_dir = Genome::Sys->create_temp_directory;

# copy to temp because the tool appears to make a large_indels.bed.dedup next
# to the original file and it doesn't seem good to have things writing in GENOME_TEST_INPUTS
my $temp_large_indels = $temp_dir."/large_indels.bed";
copy($base_dir."/large_indels.bed", $temp_large_indels)
    or die "failed to copy large_indels.bed to temp_dir: $!";

my $cmd = Genome::Model::Tools::Validation::LongIndelsGenerateMergedAssemblies->create(
    long_indel_bed_file => $temp_large_indels,
    output_dir => $temp_dir,
    transcript_variant_annotator_version => 2,
    reference_transcripts => "NCBI-human.ensembl/67_37l_v2",
    tumor_bam => $base_dir."/tumor.bam",
    normal_bam => $base_dir."/normal.bam",
    reference_fasta => "/gscmnt/ams1102/info/model_data/2869585698/build106942997/all_sequences.fa",
);

ok($cmd, "Command created successfully");
ok($cmd->execute, "Command executed successfully");

is(compare($temp_dir."/contigs.fa", $base_dir."/contigs.fa"), 0, "Output files match");

done_testing;

