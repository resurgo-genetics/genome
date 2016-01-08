#!/usr/bin/env genome-perl

use strict;
use warnings;

use Sub::Install;
use Test::Exception;
use Test::MockObject;
use Test::More tests => 2;

use above 'Genome';

my $class = 'Genome::Model::RnaSeq::Command::PicardRnaSeqMetrics';
use_ok($class) or die;

subtest 'shortcut' => sub{
    plan tests => 4;

    my $build = Test::MockObject->new;
    $build->set_always('id', 1);
    $build->isa('Genome::Model::Build');
    $build->set_always('build_id', 1);
    $build->set_always('annotation_build', undef);

    my $reference_build =  Test::MockObject->new;
    $reference_build->set_always('id', '1');
    $build->set_always('reference_build', $reference_build);

    my $alignment_result = Test::MockObject->new;
    $build->set_always('alignment_result', $alignment_result);

    my $cmd = $class->create(
        build_id => $build->id,
        build => $build,
    );
    Sub::Install::reinstall_sub({
            into => $class,
            as => 'build',
            code => sub{ $build },
        });

    # shortcut w/o annotation build
    lives_ok(sub{ $cmd->shortcut; }, 'shortcut w/o annotation build');
    like($cmd->debug_message, qr/Skipping PicardRnaSeqMetrics since annotation build is not defined/, 'correct message');

    # shortcut w/o required annotation files
    my $annotation_build = Test::MockObject->new;
    $annotation_build->set_always('rRNA_MT_file', 'foo');
    $annotation_build->set_always('annotation_file', 'foo');
    $build->set_always('annotation_build', $annotation_build);
    lives_ok(sub{ $cmd->shortcut; }, 'shortcut w/o required annotation files');
    like($cmd->debug_message, qr/Skipping PicardRnaSeqMetrics since annotation build is missing required files/, 'correct message');

};

done_testing();
