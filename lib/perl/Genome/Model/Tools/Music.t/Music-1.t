use strict;
use warnings;

use above 'Genome';
use Cwd qw(realpath);
use File::Basename qw(dirname);
use lib realpath(dirname(__FILE__));
use Test::Music qw(run_test_case);

my $input_dir = Test::Music->input_dir;
my $actual_output_dir = Test::Music->output_dir;
run_test_case(
    skip => q(Skip this tool, R arbitrarily changes precision causing expected output to differ.),
    run => "music survival\n"
        . " --numeric-clinical-data-file $input_dir/numeric_clinical_data\n"
        . " --bam-list $input_dir/bam_list\n"
        . " --maf-file $input_dir/ucec_test.maf\n"
        . " --output-dir $actual_output_dir/survival\n"
        . " --phenotypes-to-include TP53,PIK3CA",
    expect => [
        'survival/survival_analysis_data_matrix.csv',
        'survival/survival_analysis_test_results.csv'
    ],
);
