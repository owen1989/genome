#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
};

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Site::TGI::Synchronize::ReconcileMiscUpdate') or die;

my $cnt = 0;

# Default date
my $reconcile = Genome::Site::TGI::Synchronize::ReconcileMiscUpdate->create;
ok($reconcile, 'Create reconcile command to test default date');
my @errors = $reconcile->__errors__;
ok(!@errors, 'No errors for undefiined date');
diag('Default date: '.$reconcile->date);
$reconcile->delete;

# Invalid date
$reconcile = Genome::Site::TGI::Synchronize::ReconcileMiscUpdate->create(date => 'BLAH-01');
ok($reconcile, 'Create reconcile command to test invalid date');
@errors = $reconcile->__errors__;
ok(@errors, 'Errors for invalid date');
is($errors[0]->desc, 'Invalid date format => BLAH-01', 'Error tag desc is correct');
$reconcile->delete;

# Define entities
my $entity_attrs = _entity_attrs();
my $entities = _define_entities($entity_attrs);
ok($entities, 'Define entities');
my $genome_entities = map { $_->{genome_entity} } map { @{$entities->{$_}} } keys %$entities;
is($genome_entities, @$entity_attrs, "Define $genome_entities genome entities");
my $site_tgi_entities = map { $_->{site_tgi_entities} } map { @{$entities->{$_}} } keys %$entities;
is($site_tgi_entities, @$entity_attrs, "Define $site_tgi_entities site tgi entities");

# Define misc updates
my $update_params = _update_params();
my @misc_updates = _define_misc_updates($entities, $update_params);
ok(@misc_updates, 'Define misc updates');
my $update_cnt = @$update_params;
is(@misc_updates, $update_cnt, "Defined $update_cnt defined misc updates");
my @misc_indels = _define_misc_indels();
ok(@misc_indels, 'Define multi misc indels');
is(@misc_indels, 24, 'Defined 24 misc indels');
my @misc_updates_that_skip_or_fail = _define_misc_updates_that_skpip_or_fail();
ok(@misc_updates_that_skip_or_fail, 'Define misc updates that fail');

# Reconcile
$reconcile = Genome::Site::TGI::Synchronize::ReconcileMiscUpdate->create(date => '2000-01-01');
ok($reconcile, 'Create reconcile command');
@errors = $reconcile->__errors__;
ok(!@errors, 'No errors for test date');
diag('Test date: '.$reconcile->date);
ok($reconcile->execute, 'Execute reconcile command');

diag('Checking successful UPDATES...');
for my $misc_update ( @misc_updates ) {
    next if $misc_update->{_skip_check};
    my $new_value = $misc_update->new_value;
    my $genome_entity = $misc_update->genome_entity;
    my $site_tgi_class_name = $misc_update->site_tgi_class_name;
    my $genome_property_name = $site_tgi_class_name->lims_property_name_to_genome_property_name($misc_update->subject_property_name);
    is($genome_entity->$genome_property_name, $misc_update->new_value, 'Set new value ('.$new_value.') on '.$genome_entity->class.' '.$genome_entity->id);
    is($misc_update->result, 'PASS', 'Correct result');
    ok($misc_update->status, 'Set status');
    is($misc_update->is_reconciled, 1, 'Misc update correctly reconciled');
}

diag('Checking successful INDELS...');
my %multi_misc_updates_to_check;
foreach my $misc_indel ( @misc_indels ) {
    my %multi_misc_update_params = map { $_ => $misc_indel->$_ } (qw/ subject_class_name subject_id edit_date description /);
    my $multi_misc_update = Genome::Site::TGI::Synchronize::Classes::MultiMiscUpdate->get(%multi_misc_update_params);
    $multi_misc_updates_to_check{$multi_misc_update->subject_id}=$multi_misc_update;
}

for my $multi_misc_update (values %multi_misc_updates_to_check) {
    ok($multi_misc_update->perform_update, 'performed update: '.$multi_misc_update->description);
    my %genome_entity_params = $multi_misc_update->_resolve_genome_entity_params;
    ok(%genome_entity_params, 'Got genome entity params') or die;
    is(scalar(keys %genome_entity_params), 4, 'Correct number of genome entity params');
    my $genome_entity = Genome::SubjectAttribute->get(%genome_entity_params);
    if ( $multi_misc_update->description eq 'INSERT' ) {
        ok($genome_entity, 'INSERT genome entity: '.$genome_entity->__display_name__);
    }
    else {
        ok(!$genome_entity, 'DELETE genome entity: '.$multi_misc_update->__display_name__);
    }
    is($multi_misc_update->result, $multi_misc_update->description, 'Correct result');
    ok(!$multi_misc_update->error_message, 'No errors set on multi misc update!');
    is(scalar(grep {defined} map {$_->error_message} $multi_misc_update->misc_updates), 0, 'No errors set on misc updates!');
}

diag('Checking SKIP/FAILED updates...');
my ($skip_cnt, $fail_cnt, $error_cnt, $not_reconciled) = (qw/ 0 0 0 0 /);
for my $misc_update ( @misc_updates_that_skip_or_fail ) {
    $not_reconciled++ if $misc_update->is_reconciled eq 0;
    $error_cnt++ if defined $misc_update->error_message;
    if ( $misc_update->result eq 'SKIP' ) {
        $skip_cnt++;
    }
    else {#FAILED
        $fail_cnt++;
    }
}
is($skip_cnt, @misc_updates_that_skip_or_fail - $fail_cnt, 'SKIP expected number misc updates');
is($skip_cnt, @misc_updates_that_skip_or_fail - $error_cnt, 'SKIP misc updates do not have errors');
is($fail_cnt, @misc_updates_that_skip_or_fail - $skip_cnt, 'FAILED expected number of misc updates');
is($error_cnt, $fail_cnt, 'FAILED misc updates have errors');
is($not_reconciled, @misc_updates_that_skip_or_fail, 'SKIP/FAILED misc updates are not reconciled');

done_testing();


sub _entity_attrs {
    return [
        # Taxon
        { _type => 'Taxon', id => -100, estimated_genome_size => 1000, },
        { _type => 'Taxon', id => -101, estimated_genome_size => 1000, },
        # Individual
        { _type => 'Individual', id => -200, taxon_id => -100, },
        { _type => 'Individual', id => -201, taxon_id => -100, },
        { _type => 'Individual', id => -202, taxon_id => -100, },
        # Pop Group
        { _type => 'PopulationGroup', id => -300, taxon_id => -100, },
        { _type => 'PopulationGroup', id => -301, taxon_id => -100, },
        # Sample
        { _type => 'Sample', id => -400, source_id => -200, cell_type => 'primary', nomenclature => 'WUGC', is_control => 1, },
        { _type => 'Sample', id => -401, source_id => -201, cell_type => 'primary', nomenclature => 'WUGC', is_control => 1, },
        { _type => 'Sample', id => -402, source_id => -202, cell_type => 'primary', nomenclature => 'WUGC', is_control => 1, },
    ];
}

sub _define_entities {
    my $entity_attrs = shift;
    my $entities = {};
    for my $attrs ( @$entity_attrs ) {
        my $type = delete $attrs->{_type};
        $attrs->{name} = '__TEST_'.uc($type).'__',
        my $genome_class = 'Genome::'.$type;
        my $genome_entity = $genome_class->create(%$attrs);
        my $site_tgi_class = 'Genome::Site::TGI::Synchronize::Classes::'.$type;
        my $site_tgi_entity = $site_tgi_class->create(%$attrs);
        push @{$entities->{$type}}, {
            genome_entity => $genome_entity,
            site_tgi_entity => $site_tgi_entity,
        };
    }

    return $entities;
}

sub _update_params {
    return [
        # Taxon
        [ 'Taxon', 0, 'domain', 'Eukaryota' ],# is undef
        [ 'Taxon', 0, 'estimated_genome_size', '1000000' ],# has value
        [ 'Taxon', 0, 'estimated_genome_size', '5000000' ],# another value
        [ 'Taxon', 1, 'name', 'NEW_NAME' ],# has value
        # Individual
        [ 'Individual', 0, 'common_name', 'NEW_COMMON_NAME' ], # is undef
        [ 'Individual', 0, 'name', 'NEW_NAME' ], # has value
        [ 'Individual', 1, 'taxon_id', -101 ], # has value, is FK
        # PopulationGroup
        [ 'PopulationGroup', 0, 'description', 'NEW_DESCRIPTION' ], # is undef
        [ 'PopulationGroup', 0, 'name', 'NEW_NAME' ], # has value
        [ 'PopulationGroup', 1, 'taxon_id', -101 ], # has value, is FK
        # Sample
        [ 'Sample', 0, 'is_control', '1' ], # is undef
        [ 'Sample', 0, 'extraction_label', 'NEW_EXTRACTION_LABEL' ], # has value
        [ 'Sample', 1, 'source_id', -201 ],# has value, is FK
    ];
}

sub _define_misc_updates {
    my ($entities, $update_params) = @_;

    my %type_to_subject_class_name = (
        'Taxon' => 'organism_taxon',
        'PopulationGroup' => 'population_group',
        'Individual' => 'organism_individual',
        'Sample' => 'organism_sample',
    );

    my $prev_update_id = 'blah';
    my $prev_update_value = 'blah';
    my @misc_updates;
    for my $update ( @$update_params ) {
        my ($type, $pos, $property_name, $new_value) = @$update;
        my $obj = $entities->{$type}->[$pos]->{site_tgi_entity};
        next if not $obj;
        my $subject_property_name = $obj->lims_property_name_to_genome_property_name($property_name);
        my $current_update_id = join(' ', $type, $pos, $property_name);
        my $old_value = ( $prev_update_id eq $current_update_id ) ? $prev_update_value : $obj->$property_name;
        my $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->create(
            subject_class_name => 'test.'.$type_to_subject_class_name{$type},
            subject_id => $obj->id,
            subject_property_name => $subject_property_name,
            editor_id => 'lims',
            edit_date => '2000-01-01 00:00:'.sprintf('%02d', $cnt++),
            old_value => $old_value,
            new_value => $new_value,
            description => 'UPDATE',
            is_reconciled => 0,
        );
        $misc_updates[$#misc_updates]->{_skip_check} = 1 if $prev_update_id eq $current_update_id;
        $prev_update_id = $current_update_id;
        $prev_update_value = $new_value;
        push @misc_updates, $misc_update;
    }

    return @misc_updates;
}

sub _define_misc_indels {
    my %subject_class_names_to_properties= (
        population_group_member => [qw/ pg_id member_id /],
        sample_attribute => [qw/ organism_sample_id attribute_label attribute_value nomenclature /],
    );

    my @updates = (
        # PopulationGroup
        # sub_name desc pg_id member_id
        [ 'population_group_member', 'INSERT', -1000, -1001, ],
        [ 'population_group_member', 'INSERT', -1000, -1002, ],
        [ 'population_group_member', 'DELETE', -1000, -1002, ],
        [ 'population_group_member', 'INSERT', -1001, -1002, ],
        # Sample
        # sub_name desc sample_id attr_label attr_val nom
        [ 'sample_attribute', 'INSERT', -1000, 'foo', 'bar', 'baz',  ],
        [ 'sample_attribute', 'INSERT', -1001, 'foo', 'bar', 'baz',  ],
        [ 'sample_attribute', 'INSERT', -1001, 'foo', 'bar', 'qux',  ],
        [ 'sample_attribute', 'DELETE', -1000, 'foo', 'bar', 'baz',  ],
    );

    my @misc_indels;
    for my $update ( @updates ) {
        my ($subject_class_name, $description, @ids) = @$update;
        my $subject_id = join('-', @ids);
        my %params = (
            subject_class_name => 'test.'.$subject_class_name,
            subject_id => $subject_id,
            description => $description,
            edit_date => '2000-01-01 00:00:'.sprintf('%02d', $cnt++),
        );
        my $subject_property_names = $subject_class_names_to_properties{$subject_class_name};
        for ( my $i = 0; $i < @{$subject_class_names_to_properties{$subject_class_name}}; $i++ ) {
            my $misc_indel = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->create(
                %params,
                subject_property_name => $subject_class_names_to_properties{$subject_class_name}->[$i],
                editor_id => 'lims',
                old_value => $ids[$i],
                new_value => $ids[$i],
                is_reconciled => 0,
            );
            push @misc_indels, $misc_indel;
        }
    }

    return @misc_indels;
}

sub _define_misc_updates_that_skpip_or_fail {
    my @skip_or_fail;

    # Invalid genome class
    my $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.blah',
        subject_id => -100,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-01 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_TAXON__',
        new_value => 'FAILED',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    push @skip_or_fail, $misc_update;

    # No obj for subject id
    $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.organism_taxon',
        subject_id => -10000,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-01 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_TAXON__',
        new_value => 'FAILED',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    push @skip_or_fail, $misc_update;

    # Can not update sample attr
    $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.sample_attribute',
        subject_id => -100,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-01 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_SAMPLE_ATTR__',
        new_value => 'FAILED',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    push @skip_or_fail, $misc_update;

    # Can not update pop group member
    $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.population_group_member',
        subject_id => -301,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-01 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_POP_GROUP_MEMBER__',
        new_value => 'FAILED',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    push @skip_or_fail, $misc_update;

    # Old value ne to current
    $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.organism_taxon',
        subject_id => -100,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-01 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_TAXON2__',
        new_value => 'FAILED',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    push @skip_or_fail, $misc_update;

    # Unsupported attr
    $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.organism_sample',
        subject_id => -100,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-01 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_SAMPLE__',
        new_value => 'SKIP',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    push @skip_or_fail, $misc_update;

    return @skip_or_fail;
}
