use strict;
use warnings;

BEGIN {
    $ENV{NO_LSF}                         = 1;
    $ENV{UR_DBI_NO_COMMIT}               = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above 'Genome';
use Genome::SoftwareResult;

use Test::More;
use Test::Exception;
use File::Compare qw(compare);
use Genome::Utility::Test qw(compare_ok);

my $VERSION = 2;

my $pkg = 'Genome::Model::Tools::DetectVariants2::Lumpy';
use_ok($pkg);

my $refbuild_id = 101947881;
my $test_dir    = Genome::Utility::Test->data_dir($pkg, $VERSION);
my $output_dir  = Genome::Sys->create_temp_directory();
my $tumor_bam   = File::Spec->join($test_dir, 'tumor.bam');

my $command = Genome::Model::Tools::DetectVariants2::Lumpy->create(
    reference_build_id  => $refbuild_id,
    aligned_reads_input => $tumor_bam,
    params              => join('//',
        '-lp,-mw:4,-tt:0.0',
        '-pe,min_non_overlap:150,discordant_z:4,back_distance:20,weight:1',
        '-sr,back_distance:20,weight:1,min_mapping_threshold:20'
    ),
    output_directory    => $output_dir,
    version             => "0.2.6",
);
ok($command, 'Created `gmt detect-variants2 Lumpy` command');

subtest 'Directories and input files as expected' => sub {
    my $expected_lumpy_directory = File::Spec->join(File::Spec->rootdir, 'usr', 'lib', 'lumpy0.2.6');
    is(
        $command->lumpy_directory,
        $expected_lumpy_directory,
        'Lumpy directory as expected'
    );

    is(
        $command->lumpy_scripts_directory,
        File::Spec->join($expected_lumpy_directory, 'scripts'),
        'Lumpy scripts directory as expected'
    );

    is(
        $command->lumpy_script_for_extract_split_reads_bwamem,
        File::Spec->join($command->lumpy_scripts_directory, 'extractSplitReads_BwaMem'),
        'Lumpy script for split reads location as expected'
    );

    is(
        $command->lumpy_script_for_pairend_distro,
        File::Spec->join($command->lumpy_scripts_directory, 'pairend_distro.py'),
        'Lumpy script for paired end location as expected'
    );

    is(
        $command->lumpy_command,
        File::Spec->join($expected_lumpy_directory, 'bin', 'lumpy'),
        'Lumpy base command as expected'
    );
};

subtest 'parameter parsing' => sub {
    is($command->split_read_base_params, 'back_distance:20,weight:1,min_mapping_threshold:20', 'Split read parameters as expected');
    is($command->paired_end_base_params, 'min_non_overlap:150,discordant_z:4,back_distance:20,weight:1', 'Pair end parameters as expected');
    is($command->lumpy_base_params, '-mw 4 -tt 0.0', 'Lumpy parameters as expected');
    my $command2 = Genome::Model::Tools::DetectVariants2::Lumpy->create(
        reference_build_id  => $refbuild_id,
        params              => '-test,-mw:4,-tt:0.0',
        output_directory    => $output_dir,
        version             => "0.2.6",
    );
    dies_ok(sub {$command2->params_hash}, 'Lumpy command with malformed parameters dies');
};

subtest 'read group values' => sub {
    my ($id, $lib) = $command->extract_id_and_lib_values($tumor_bam);
    is($id, '2883581792-2883255521', 'ID value extracted correctly');
    is($lib, 'TEST-patient1-somval_tumor1-extlibs', 'LB value extracted correctly');
};

subtest "Execute" => sub {
    ok($command->execute, 'Executed `gmt detect-variants2 lumpy` command');
    compare_ok(
        File::Spec->join($output_dir, 'svs.hq'),
        File::Spec->join($test_dir, '1_svs.hq'),
        'Output file as expected'
    );
    compare_ok(
        File::Spec->join($output_dir, 'legend.tsv'),
        File::Spec->join($test_dir, 'legend.tsv'),
        'Legend file as expected'
    );
};

subtest "test file without split reads" => sub {
    my $wo_sr_bam   = File::Spec->join($test_dir, 'medlarge2.bam');
    my $output_dir2 = Genome::Sys->create_temp_directory();

    my $command2 = Genome::Model::Tools::DetectVariants2::Lumpy->create(
        reference_build_id  => $refbuild_id,
        aligned_reads_input => $wo_sr_bam,
        params              => join('//',
            '-lp,-mw:4,-tt:0.0',
            '-pe,min_non_overlap:150,discordant_z:4,back_distance:20,weight:1',
            '-sr,back_distance:20,weight:1,min_mapping_threshold:20'
        ),
        output_directory    => $output_dir2,
        version             => "0.2.6",
    );
    ok($command2, 'Created `gmt detect-variants2 Lumpy` command');
    ok($command2->execute, 'Executed `gmt detect-variants2 lumpy` command');
    compare_ok(
        File::Spec->join($output_dir2, 'svs.hq'),
        File::Spec->join($test_dir, 'wo_sr1_svs.hq'),
        'Output file as expected'
    );
    compare_ok(
        File::Spec->join($output_dir2, 'legend.tsv'),
        File::Spec->join($test_dir, 'legend.split_reads.tsv'),
        'Legend file as expected'
    );
};

subtest "test matched samples" => sub {
    my $wo_sr_bam   = File::Spec->join($test_dir, 'medlarge2.bam');
    my $output_dir2 = Genome::Sys->create_temp_directory();

    my $command2 = Genome::Model::Tools::DetectVariants2::Lumpy->create(
        reference_build_id          => $refbuild_id,
        aligned_reads_input         => $wo_sr_bam,
        control_aligned_reads_input => $tumor_bam,
        params => join('//',
            '-lp,-mw:4,-tt:0.0',
            '-pe,min_non_overlap:150,discordant_z:4,back_distance:20,weight:1',
            '-sr,back_distance:20,weight:1,min_mapping_threshold:20'
        ),
        output_directory => $output_dir2,
        version          => "0.2.6",
    );
    ok($command2, 'Created `gmt detect-variants2 Lumpy` command');
    ok($command2->execute, 'Executed `gmt detect-variants2 Lumpy` command');
    compare_ok(
        File::Spec->join($output_dir2, 'svs.hq'),
        File::Spec->join($test_dir, 'match_svs.hq'),
        'Output file as expected'
    );
    compare_ok(
        File::Spec->join($output_dir2, 'legend.tsv'),
        File::Spec->join($test_dir, 'legend.matched.tsv'),
        'Legend file as expected'
    );
};

subtest "has version test" => sub {
    ok(Genome::Model::Tools::DetectVariants2::Lumpy->has_version("0.2.6"), 'Lumpy version is 0.2.6');
    ok(!Genome::Model::Tools::DetectVariants2::Lumpy->has_version("0.2.10"), 'Lumpy version is not 0.2.10');
};

subtest "paired_end_parameters_for_bam" => sub {
    my $bam                = "test_bam";
    my $histogram          = "test_histogram_file";
    my $mean               = 123;
    my $standard_deviation = 456;
    my $read_length        = 99;
    my $id                 = 1;

    Sub::Install::reinstall_sub(
        {
            into => 'Genome::Model::Tools::DetectVariants2::Lumpy',
            as   => 'extract_paired_end_reads',
            code => sub {return $bam;},
        }
    );

    Sub::Install::reinstall_sub(
        {
            into => 'Genome::Model::Tools::DetectVariants2::Lumpy',
            as   => 'calculate_metrics',
            code => sub {return (
                mean => $mean,
                standard_deviation => $standard_deviation,
                histogram => $histogram,
                read_length => $read_length,
            );},
        }
    );

    is(
        $command->paired_end_parameters_for_bam($bam, $id),
        sprintf(
            ' -pe bam_file:%s,histo_file:%s,mean:%s,stdev:%s,read_length:%s,id:%s,%s',
            $bam,
            $histogram,
            $mean,
            $standard_deviation,
            $read_length,
            $id,
            $command->paired_end_base_params
        ),
        'Command as expected',
    );
};

subtest "split_read_parameters_for_bam" => sub {
    my $bam = "test_bam";
    my $id  = 1;

    Sub::Install::reinstall_sub(
        {
            into => 'Genome::Model::Tools::DetectVariants2::Lumpy',
            as   => 'extract_split_reads',
            code => sub {return $bam;},
        }
    );

    is(
        $command->split_read_parameters_for_bam($bam, $id),
        sprintf(
            ' -sr bam_file:%s,id:%s,%s',
            $bam,
            $id,
            $command->split_read_base_params
        ),
        'Command as expected'
    );
};

done_testing();
