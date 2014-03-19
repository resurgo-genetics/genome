#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
};

use above 'Genome';

use Test::More;

use_ok('Genome::Model::GenotypeMicroarray::Command::ExtractToCsv') or die;
use_ok('Genome::Model::GenotypeMicroarray::Test') or die;

my $build = Genome::Model::GenotypeMicroarray::Test::example_build();
my $variation_list_build = $build->dbsnp_build;
my $instrument_data = $build->instrument_data;

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
my $output_tsv = $tmpdir.'/genotypes';

# no build
my $extract = Genome::Model::GenotypeMicroarray::Command::ExtractToCsv->create();
ok(!$extract->execute, 'failed to create command w/o source');
is($extract->error_message, "Property 'build': No value specified for required property", 'correct error');

done_testing();
