#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

use File::Path;
use File::Temp;
use Test::More;
use above 'Genome';
use Genome::SoftwareResult;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from a 64-bit machine";
}

use_ok('Genome::Model::Tools::DetectVariants2::Mutect');

my $refbuild_id = 106942997;
my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get($refbuild_id);
ok($ref_seq_build, 'GRCh37-lite-build37 reference sequence build') or die;

my $tumor = "/gscmnt/sata831/info/medseq/dlarson/mutect_testing/tiny.tumor.custom_header.bam";
my $normal = "/gscmnt/sata831/info/medseq/dlarson/mutect_testing/tiny.normal.custom_header.bam";

#Define path to a custom reference sequence build dir
my $custom_reference_dir = "/gscmnt/sata831/info/medseq/dlarson/mutect_testing/" . "custom_reference";
ok(-e $custom_reference_dir, "Found the custom reference dir: $custom_reference_dir");

#Use small reference sequence build by setting up a custom reference genome model
my $reduced_ref_seq_build = Genome::Model::Build::ReferenceSequence->create(
    model => $ref_seq_build->model,
    version => "37",
    data_directory => $custom_reference_dir,
);
ok($reduced_ref_seq_build, "Created a reduced reference sequence build for testing") or die;
#my $tumor =  $ENV{GENOME_TEST_INPUTS} . "/Genome-Model-Tools-DetectVariants-Mutect/tiny.tumor.bam";
#my $normal = $ENV{GENOME_TEST_INPUTS} . "/Genome-Model-Tools-DetectVariants-Mutect/tiny.normal.bam";
#
#my $test_base_dir = File::Temp::tempdir('MutectXXXXX', CLEANUP => 0, TMPDIR => 1);
my $test_base_dir = "/gscmnt/sata831/info/medseq/dlarson/mutect_testing/output_directory";

my $mutect = Genome::Model::Tools::DetectVariants2::Mutect->create(aligned_reads_input=>$tumor, 
                                                                   control_aligned_reads_input=>$normal,
                                                                   output_directory => $test_base_dir,
                                                                   reference_build_id => $reduced_ref_seq_build->id,
                                                                   version => 'test',
                                                                   params => '--number-of-chunks 5;--intervals 13:32903269-32923269',
                                                                   );
ok($mutect, 'mutect command created');
$mutect->dump_status_messages(1);
my $rv = $mutect->execute;
#is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);
#my $fasta = Genome::File::Fasta->create(id => '/gscmnt/ams1102/info/model_data/2869585698/build106942997/all_sequences.fa');
#my $wrapper = Genome::Model::Tools::Mutect::ParallelWrapper->create(tumor_bam=>$tumor, 
#                                                                  normal_bam=>$normal,
#                                                                   reference => $fasta->path,
#                                                                   chunk_num => 4,
#                                                                   total_chunks => 5,
#                                                                   fasta_object => $fasta,
#                                                                   basename => "/tmp/test",
#                                                                   );
#                                                                   $wrapper->execute;
#my $output_snv_file = $sniper->output_directory . "/snvs.hq.bed";
$DB::single = 1;
#my $output_indel_file = $sniper->output_directory . "/indels.hq.bed";
#
#ok(-s $output_snv_file,'Testing success: Expecting a snv output file exists');
#ok(-s $output_indel_file,'Testing success: Expecting a indel output file exists');
#
##I don't know what this output should like like, but we will check to see if this runs...
#my $v1_test_working_dir = "$test_base_dir/output_v1";
#my $sniper_v1 = Genome::Model::Tools::DetectVariants2::Sniper->create(aligned_reads_input=>$tumor, 
#                                                                      control_aligned_reads_input=>$normal,
#                                                                      reference_build_id => $refbuild_id,
#                                                                      output_directory => $v1_test_working_dir,
#                                                                      version => '1.0.2',
#                                                                      params => '-F vcf -q 1 -Q 15',
#                                                                      aligned_reads_sample => 'TEST',);
#ok($sniper_v1, 'sniper 1.0.2 command created');
#$sniper_v1->dump_status_messages(1);
#my $rv1= $sniper_v1->execute;
#is($rv1, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv1);
#
done_testing();
