#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::Utility::Test;

my $class = "Genome::Model::Tools::ChimeraScan::FilterOutput";

use_ok($class);
my $data_dir = Genome::Utility::Test->data_dir_ok($class, "v3");
my $in = $data_dir."/chimeras.bedpe";
my $out = Genome::Sys->create_temp_file_path;
my $expected = $data_dir."/expected.txt";

my $rt = $class->execute(bedpe_file => $in, output_file => $out);
Genome::Utility::Test::compare_ok($out, $expected, "Output file was created as expected");

done_testing;
