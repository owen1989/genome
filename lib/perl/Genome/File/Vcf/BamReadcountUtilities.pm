package Genome::File::Vcf::BamReadcountUtilities;

use strict;
use warnings FATAL => 'all';
use Genome;
use Genome::Utility::Vcf qw(convert_indel_gt_to_bed);

sub vcf_entry_to_allele_offsets {
    my ($entry) = @_;
    my @offsets;
    for my $allele (@{$entry->{alternate_alleles}}) {
        if (length($allele) == length($entry->{reference_allele})) {
           push @offsets, 0;
        }
        else {
            my (undef, $shifts) = convert_indel_gt_to_bed($entry->{reference_allele}, $allele);
            push @offsets, adjusted_offset($entry->{reference_allele}, $allele, $shifts->[0]);
        }
    }
    return @offsets;
}

sub adjusted_offset {
    my ($ref, $alt, $offset) = @_;
    if (!defined $offset) {
        return 0;
    }
    if (_is_deletion($ref, $alt)) {
        return $offset;
    }
    else {
        return $offset - 1;
    }
}

sub _is_deletion {
    my ($ref, $allele) = @_;
    if (length($ref) > length($allele)) {
        return 1;
    }
    return 0;
}

sub vcf_entry_to_readcount_positions {
    my ($entry) = @_;
    my $pos = $entry->{position};
    my %positions = map { $pos + $_ => 1 } vcf_entry_to_allele_offsets($entry);
    return sort { $a <=> $b } keys %positions;
}

sub entries_match {
    my ($readcount_entry, $vcf_entry) = @_;

    if (defined $readcount_entry) {
        my $rc_chrom  = $readcount_entry->chromosome;
        my $rc_pos    = $readcount_entry->position;
        my $vcf_chrom = $vcf_entry->{chrom};
        if ($rc_chrom eq $vcf_chrom) {
            my @positions = vcf_entry_to_readcount_positions($vcf_entry);
            for my $vcf_pos (@positions) {
                if ($rc_pos == $vcf_pos) {
                    return 1;
                }
            }
        }
    }
    return 0;
}

1;
