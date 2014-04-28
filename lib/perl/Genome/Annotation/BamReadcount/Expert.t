#!/usr/bin/env genome-perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use above 'Genome';
use Genome::File::Vcf::Differ;
use Genome::Utility::Test qw(compare_ok);
use Genome::Annotation::TestHelpers qw(
    get_test_somatic_variation_build
    test_dag_xml
    test_dag_execute
    get_test_dir
);
use Genome::Annotation::Plan::TestHelpers qw(
    set_what_interpreter_x_requires
);

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

my $pkg = 'Genome::Annotation::BamReadcount::Expert';
use_ok($pkg) || die;

my $VERSION = 4; # Bump these each time test data changes
my $BUILD_VERSION = 1;
my $test_dir = get_test_dir($pkg, $VERSION);

my $expert = $pkg->create();
my $dag = $expert->dag();
my $expected_xml = File::Spec->join($test_dir, 'expected.xml');
test_dag_xml($dag, $expected_xml);

set_what_interpreter_x_requires('bam-readcount');
my $variant_type = 'snvs';
my $expected_vcf = File::Spec->join($test_dir, "expected_$variant_type.vcf.gz");
my $build = get_test_somatic_variation_build($BUILD_VERSION, File::Spec->join($test_dir, 'plan.yaml'));
test_dag_execute($dag, $expected_vcf, $variant_type, $build);

done_testing();
