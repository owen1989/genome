#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Test::Exception;
use Genome::File::Vcf::Entry;
use Genome::VariantReporting::Expert::BamReadcount::TestHelper qw(bam_readcount_line create_entry);

my $pkg = 'Genome::VariantReporting::Expert::BamReadcount::VafInterpreter';
use_ok($pkg);

subtest "one alt allele" => sub {
    my $interpreter = $pkg->create(sample_name => "S1");
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected = (
        G => {
            vaf => 1,
            ref_count => 3,
            var_count => 341,
        }
    );

    my $entry = create_entry(bam_readcount_line);
    cmp_ok({$interpreter->interpret_entry($entry, ['G'])}->{G}->{vaf}, ">", 99);
    cmp_ok({$interpreter->interpret_entry($entry, ['G'])}->{G}->{vaf},  "<", 100);
    is({$interpreter->interpret_entry($entry, ['G'])}->{G}->{ref_count}, $expected{G}->{ref_count});
    is({$interpreter->interpret_entry($entry, ['G'])}->{G}->{var_count}, $expected{G}->{var_count});
};

subtest "Passed allele doesn't have bam-readcount" => sub {
    my $interpreter = $pkg->create(sample_name => "S1");
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected_return_values = (
        C => {
            vaf => undef,
            ref_count => 3,
            var_count => 1,
        }
    );

    my $entry = create_entry(bam_readcount_line);
    is_deeply({$interpreter->interpret_entry($entry, ['C'])}, \%expected_return_values);
};
done_testing;
