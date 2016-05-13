#!/usr/bin/env genome-perl

#Written by Malachi Griffith

use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}               = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above "Genome";
use Test::More tests => 11;  #One per 'ok', 'is', etc. statement below
use Genome::Model::ClinSeq::Command::CreateMutationSpectrum;
use Data::Dumper;
use Genome::Model::ClinSeq::TestData;
use Genome::Utility::Test;
use Sub::Override;

my $pkg = 'Genome::Model::ClinSeq::Command::CreateMutationSpectrum';
use_ok($pkg);

use Genome::Model::Build::ReferenceSequence;
my $override = Sub::Override->new(
    'Genome::Model::Build::ReferenceSequence::full_consensus_path',
    sub { return '/gscmnt/ams1102/info/model_data/2869585698/build106942997/all_sequences.fa'; }
);

#Define the test where expected results are stored
my $expected_output_dir = Genome::Utility::Test->data_dir_ok($pkg, 'wgs/2016-05-13');

#Create a temp dir for results
my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir") or die;

#Get a ClinSeq somatic variation build
my $test_data = Genome::Model::ClinSeq::TestData->load();
my $clinseq_build_id = $test_data->{CLINSEQ_BUILD};
my $clinseq_build    = Genome::Model::Build->get($clinseq_build_id);
ok($clinseq_build, "obtained clinseq build from db") or die;

#Get a wgs somatic variation build
my $somvar_build_id = $test_data->{WGS_BUILD};
my $somvar_build    = Genome::Model::Build->get($somvar_build_id);
ok($somvar_build, "obtained somatic variation build from db") or die;

#Get a 'final' name for the sample
my $final_name = $somvar_build->model->id;
$final_name = $somvar_build->model->subject->name if ($somvar_build->model->subject->name);
$final_name = $somvar_build->model->subject->individual->common_name
    if ($somvar_build->model->subject->individual->common_name);
ok($final_name, "found final name from build object") or die;

#Create create-mutation-spectrum command and execute
my $mutation_spectrum_cmd = $pkg->create(
    outdir         => $temp_dir,
    datatype       => 'wgs',
    somatic_build  => $somvar_build,
    clinseq_build  => $clinseq_build,
    test           => 1
);
$mutation_spectrum_cmd->queue_status_messages(1);
my $r1 = $mutation_spectrum_cmd->execute();
is($r1, 1, 'Testing for successful execution.  Expecting 1.  Got: ' . $r1);

#Dump the output to a log file
my @output1  = $mutation_spectrum_cmd->status_messages();
my $log_file = $temp_dir . "/wgs/CreateMutationSpectrum.wgs.log.txt";
my $log      = IO::File->new(">$log_file");
$log->print(join("\n", @output1));
ok(-e $log_file, "Wrote message file from update-analysis to a log file: $log_file");

#The first time we run this we will need to save our initial result to diff against
#Genome::Sys->shellcmd(cmd => "cp -r -L $temp_dir/* $expected_output_dir");

#Check for non-zero presence of expected PDFs
my $pdf3 =
    $temp_dir . "/wgs/mutation_spectrum_sequence_context/" . "$final_name" . ".mutation-spectrum-sequence-context.pdf";
ok(-s $pdf3, "Found non-zero PDF file mutation-spectrum-sequence-context.pdf");

my $pdf4 = $temp_dir . "/wgs/summarize_mutation_spectrum/" . "$final_name" . "_summarize-mutation-spectrum.pdf";
ok(-s $pdf4, "Found non-zero PDF file summarize-mutation-spectrum.pdf");

#Perform a diff between the stored results and those generated by this test
my @diff =
    `diff -r -x '*.log.txt' -x '*.pdf' -x '*.stderr' -x '*.stdout' -x '*.input.tsv' $expected_output_dir $temp_dir`;
my $ok = ok(@diff == 0, "Found only expected number of differences between expected results and test results");
unless ($ok) {
    diag("expected: $expected_output_dir\nactual: $temp_dir\n");
    diag("differences are:");
    diag(@diff);
    my $diff_line_count = scalar(@diff);
    print "\n\nFound $diff_line_count differing lines\n\n";
    Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-create-mutation-spectrum-wgs-result/");
    Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-create-mutation-spectrum-wgs-result");
}

done_testing();
