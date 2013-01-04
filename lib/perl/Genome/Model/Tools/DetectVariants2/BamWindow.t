#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{NO_LSF} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use File::Path;
use File::Temp;
use Test::More tests => 6;
use above 'Genome';
use Genome::SoftwareResult;
use File::Compare;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
}

use_ok('Genome::Model::Tools::DetectVariants2::BamWindow');

my $testbam =  $ENV{GENOME_TEST_INPUTS} . "/Genome-Model-Tools-DetectVariants2-BamWindow/tumor.bam";
my $expected_output = $ENV{GENOME_TEST_INPUTS} . "/Genome-Model-Tools-DetectVariants2-BamWindow/expected_v0.4/readcounts.wind";

my $tmpbase = File::Temp::tempdir('BamWindowXXXXX', DIR => "$ENV{GENOME_TEST_TEMP}/", CLEANUP => 1);
my $tmpdir = "$tmpbase/output";

my $bamwindow = Genome::Model::Tools::DetectVariants2::BamWindow->create(
    aligned_reads_input=>$testbam, 
    output_directory => $tmpdir, 
    aligned_reads_sample => "TEST",
    reference_build_id => 106942997,
    version => '0.4',
    aligned_reads_input => $testbam,
    params => '-r -l -w 100000',
);

ok($bamwindow, 'bamwindow command created');

$ENV{NO_LSF}=1;

$bamwindow->dump_status_messages(1);
my $rv = $bamwindow->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

my $output_cnv_file = $bamwindow->output_directory . "/readcounts.wind";


ok(-s $output_cnv_file,'Testing success: Expecting that a cnv output file exists');

# Look for the result
my $result = $bamwindow->_result;
ok($result, "Got a software result");


if(defined($ARGV[0])){
    if($ARGV[0] eq "createResult"){
        `cp $output_cnv_file $expected_output`;
    }
}

is(compare($output_cnv_file, $expected_output), 0, 'Output was identical to expected output.');

done_testing();
