#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';
use Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb;
use Genome::Disk::Allocation;

use Test::More tests => 4;


subtest 'default values' => sub {
    plan tests => 3;

    my $expected_dbname = 'rgekrjgekrjg';
    my $expected_host = 'foo-db-host.example.com';
    my $expected_port = '8394';
    local $ENV{XGENOME_DS_GMSCHEMA_SERVER} = qq(dbname=${expected_dbname};host=${expected_host};port=${expected_port});

    is(Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb::_get_default_database_name(),
        $expected_dbname,
        'dbname');
    is(Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb::_get_default_database_server(),
        $expected_host,
        'host');
    is(Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb::_get_default_database_port(),
        $expected_port,
        'port');
};

subtest 'collect_newly_created_allocations' => sub {
    plan tests => 3;

    my $cmd = Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb->create();
    ok($cmd, 'created Command');

    no warnings 'redefine';

    # we're not using real databases for this test
    local *Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb::disconnect_database_handles = sub {};

    local *Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb::_make_iterator_for_template_allocations = sub {
        make_allocation_iterator_from_list(qw(b c e f i j o));
    };

    local *Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb::_make_iterator_for_database_allocations = sub {
        make_allocation_iterator_from_list(qw(a b c e f h i j k m o));
    };

    local *Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb::_make_check_for_production_allocation = sub {
        return sub { return($_[0] eq 'm') }  # allocation 'm' was "created", but exists in production too
    };

    my @expected = map { Genome::Disk::StrippedDownAllocation->new(id => $_, kilobytes_requested => 1) } qw(a h k);
    my @got = $cmd->collect_newly_created_allocations();
    is_deeply(\@got,
              \@expected,
              'got differences');

    local *Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb::_make_iterator_for_template_allocations = sub {
        make_allocation_iterator_from_list(qw(b c e f i j));
    };

    local *Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb::_make_iterator_for_database_allocations = sub {
        make_allocation_iterator_from_list(qw(b c e f i j));
    };
    @got = $cmd->collect_newly_created_allocations();
    is_deeply([],
              \@got,
              'no differences');
};

subtest 'report_allocations_to_delete' => sub {
    plan tests => 2;

    my $cmd = Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb->create();
    $cmd->dump_status_messages(0);
    $cmd->queue_status_messages(1);

    my $three_gb_in_kb = 3 * 1024 * 1024;
    my $one_gb_in_kb = 1024 * 1024;
    my @allocations = ( Genome::Disk::StrippedDownAllocation->new(id => 'a', kilobytes_requested => $three_gb_in_kb),
                        Genome::Disk::StrippedDownAllocation->new(id => 'b', kilobytes_requested => $three_gb_in_kb),
                        Genome::Disk::StrippedDownAllocation->new(id => 'c', kilobytes_requested => $one_gb_in_kb),
                      );

    $cmd->report_allocations_to_delete(@allocations);
    is_deeply([ $cmd->status_messages ],
              [ 'Removing 7.000 GB in 3 allocations.'],
              'report on deleted allocations');


    $cmd->report_allocations_to_delete();
    is_deeply([ $cmd->status_messages ],
              [ 'Removing 7.000 GB in 3 allocations.',
                'Removing 0.000 GB in 0 allocations.' ],
              'Report when no allocations are to be deleted');
};

subtest 'delete_allocations' => sub {
    plan tests => 2;

    my @allocation_ids = qw(a b c d);
    my @allocations_to_delete = map { Genome::Disk::StrippedDownAllocation->new(id => $_, kilobytes_requested => 1) }
                                @allocation_ids;
    my $manager = Genome::Disk::FakeAllocationManager->create(@allocations_to_delete);
    my $cmd = Genome::Model::Command::Admin::RemoveDiskAllocationsFromTestdb->create();
    is( $cmd->delete_allocations(@allocations_to_delete),
        1,
        'delete allocations function');

    is_deeply( [ map { $_->id } $manager->deleted_allocations ],
               \@allocation_ids,
               'called delete() on all the allocation objects');

};

sub make_allocation_iterator_from_list {
    my @list = @_;
    return sub {
        my $alloc_id = shift @list;
        return unless defined $alloc_id;
        return Genome::Disk::StrippedDownAllocation->new(id => $alloc_id, kilobytes_requested => 1);
    };
}



package Genome::Disk::FakeAllocationManager;

use Scalar::Util qw(weaken);

my @fake_allocations;
my @deleted_allocations;

use constant original_genome_disk_allocation_get => Genome::Disk::Allocation->can('get');

sub create {
    my $class = shift;

    do { Genome::Disk::FakeAllocation->create_from_stripped_allocation($_) } foreach @_;

    no warnings 'redefine';
    *Genome::Disk::Allocation::get = \&Genome::Disk::FakeAllocation::get;

    return bless \$class, $class;
}

sub DESTROY {
    my $self = shift;

    @fake_allocations = ();
    @deleted_allocations = ();

    no warnings 'redefine';
    *Genome::Disk::Allocation::get = original_genome_disk_allocation_get;
}

sub allocations {
    return @fake_allocations;
}

sub deleted_allocations {
    return @deleted_allocations;
}

package Genome::Disk::FakeAllocation;

sub create_from_stripped_allocation {
    my($class, $stripped_alloc) = @_;
    my $self = { id => $stripped_alloc->id, kilobytes_requested => $stripped_alloc->kilobytes_requested};

    push @fake_allocations, $self;
    return bless $self, $class;
}

sub id {
    my $self = shift;
    return $self->{id};
}

sub kilobytes_requested {
    my $self = shift;
    return $self->{kilobytes_requested};
}

sub get {
    unless (@_ == 2
        or
        ( @_ == 3 and $_[1] eq 'id' and ref($_[2]) eq 'ARRAY')
    ) {
        die 'Unexpected args passed to get(), expected only ($class, $id) or ($class, $id, arrayref) but got '
            . join(', ', @_);
    }

    my $class = shift;

    my %ids;
    if ($_[0] eq 'id') {
        %ids = map { $_ => 1 } @{ $_[1] };
    } else {
        $ids{$_[0]} = 1;
    }
    my @alloc = grep { exists $ids{$_->id} } @fake_allocations;
    unless (@alloc) {
        die "Couldn't find fake allocation with id " . join(', ', keys %ids) . " in get()";
    }
    if (wantarray) {
        return @alloc;
    } else {
        if (@alloc > 1) {
            die "Returning ".scalar(@alloc)." allocations in scalar context";
        }
        return $alloc[0];
    }
}

sub delete {
    my $self = shift;

    my $id = $self->id;
    for (my $i = 0; $i < @fake_allocations; $i++) {
        if ($fake_allocations[$i]->id eq $id) {
            splice(@fake_allocations, $i, 1);
            push @deleted_allocations, $self;
            return $self;
        }
    }
    die "Couldn't find fake allocation with id $id in delete()";
}

