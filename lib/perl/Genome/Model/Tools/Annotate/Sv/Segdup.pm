package Genome::Model::Tools::Annotate::Sv::Segdup;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Annotate::Sv::Segdup {
    is => "Genome::Model::Tools::Annotate::Sv::IntervalAnnotator",
    has_input => [
        annotation_file => {
            is => 'String',
            doc => 'File containing UCSC table',
            default => "/gsc/scripts/share/BreakAnnot_file/human_build37/Human.Feb2009.SegDups.tab",
        }
    ],
};

sub process_breakpoint_list {
    my ($self, $breakpoints_list) = @_;
    my %output;
    my $segdup_annotation = $self->read_segdup_annotation($self->annotation_file);
    $self->annotate_interval_matches($breakpoints_list, $segdup_annotation, $self->breakpoint_wiggle_room, "segdup_annotation", "bpA");
    $self->annotate_interval_matches($breakpoints_list, $segdup_annotation, $self->breakpoint_wiggle_room, "segdup_annotation", "bpB");
    foreach my $chr (keys %{$breakpoints_list}) {
        foreach my $item (@{$breakpoints_list->{$chr}}) {
            my $key = $self->get_key_from_item($item);
            $output{$key} = [$self->get_segdup_annotation($item)];
            #if (defined $item->{segdup_annotation}) {
            #    my @segdup = map {$_->{name}} @{$item->{segdup_annotation}};
            #    $output{$key} = [join(",", @segdup)];
            #}
            #else {
            #    $output{$key} = ["N/A"];
            #}
        }
    }
    return \%output;
}

sub column_names {
    return ('segdup');
}

sub read_segdup_annotation{
    my ($self, $file) = @_;
    my %annotation;
    my $in = Genome::Sys->open_file_for_reading($file) || die "Unable to open annotation: $file\n";
    while (my $line = <$in>) {
        chomp $line;
        next if $line =~ /^\#/;
        my $p;
        my @fields = split /\t+/, $line;
        $p->{chrom} = $fields[1];
        $p->{chromStart} = $fields[2];
        $p->{chromEnd} = $fields[3];
        $p->{name} = $fields[17];
        $p->{chrom} =~ s/chr//;
        push @{$annotation{$p->{chrom}}{$p->{chromEnd}}{$p->{chromStart}}}, $p;
    }
    $in->close;
    return \%annotation;
}

sub get_segdup_annotation {
    my ($self, $item) = @_;
    my (@e1s, @e2s);

    if (defined $item->{segdup_annotation}) {
        if (defined $item->{segdup_annotation}->{bpA}) {
            @e1s = @{$item->{segdup_annotation}->{bpA}}; 
        }
        if (defined $item->{segdup_annotation}->{bpB}) {
            @e2s = @{$item->{segdup_annotation}->{bpB}}; 
        }
    }
    else {
        return "N/A";
    }

    my ($e1, $e2);

    foreach my $end1 (@e1s) {
        foreach my $end2 (@e2s) {
            if ($end1->{name} eq $end2->{name}) {
                $e1 = $end1;
                $e2 = $end2;
            }
        }
    }

    unless (defined $e1) {
        foreach my $end1 (@e1s) {
            if ((!defined $e1) or abs($e1->{chromStart} - $e1->{chromEnd} + 1) < abs($end1->{chromStart} - $end1->{chromEnd} + 1)) {
                $e1 = $end1;
            }
        }
    }

    unless (defined $e2) {
        foreach my $end2 (@e2s) {
            if ((!defined $e2) or abs($e2->{chromStart} - $e2->{chromEnd} + 1) < abs($end2->{chromStart} - $end2->{chromEnd} + 1)) {
                $e2 = $end2;
            }
        }
    }

    my $segdup = sprintf "%s\-%s", $e1->{name}||'N/A', $e2->{name}|| 'N/A';
    return $segdup;
}

1;

