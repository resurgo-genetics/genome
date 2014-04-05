#!/usr/bin/env perl

use above 'Genome';
use Data::Dumper;
use Test::More;

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

my $pkg = "Genome::File::Vcf::Header";

use_ok($pkg);

my $header_txt = <<EOS;
##fileformat=VCFv4.1
##foo=bar
##something
##FILTER=<ID=PASS,Description="Passed all filters">
##FILTER=<ID=BAD,Description="Badness">
##FILTER=<ID=REALLY_BAD,Description="Oh no">
##INFO=<ID=CALLER,Number=.,Type=String,Description="Variant caller">
##INFO=<ID=GMAF,Number=A,Type=Float,Description="Global minor allele frequency">
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Read depth">
##SAMPLE=<Accession=hhh000034,File=TCGA-1.bam,ID=TCGA-1,Platform=Illumina,SampleTCGABarcode=TCGA-1,SampleUUID=536-345-5dc-8234,Source=dbGap>
##vcfProcessLog=<InputVCFSource=<Samtools>>
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	S1	S2	S3
EOS
my @lines = split("\n", $header_txt);

subtest "basic_parse" => sub {
    my $header = $pkg->create(lines => \@lines);
    ok($header, "Parsed header");

    is($header->fileformat, "VCFv4.1", "fileformat");
    is($header->num_samples, 3, "got 3 samples");
    is(scalar $header->sample_names, 3, "got 3 samples");
    is_deeply([$header->sample_names], ["S1", "S2", "S3"], "Sample names parsed");

    is_deeply([sort keys %{$header->info_types}], ["CALLER", "GMAF"], "Got expected info field names");
    is_deeply([sort keys %{$header->format_types}], ["DP", "GT"], "Got expected format field names");
    is_deeply([sort keys %{$header->filters}], ["BAD", "PASS", "REALLY_BAD"], "Got expected filter names");

    is_deeply($header->info_types->{CALLER},
        {
            id => "CALLER",
            number => ".",
            type => "String",
            description => "Variant caller",
        }
        , "caller info field");

    is_deeply($header->info_types->{GMAF},
        {
            id => "GMAF",
            number => "A",
            type => "Float",
            description => "Global minor allele frequency",
        }
        , "caller info field");

    is_deeply($header->format_types->{GT},
        {
            id => "GT",
            number => "1",
            type => "String",
            description => "Genotype",
        }
        , "caller format field");

    is_deeply($header->format_types->{DP},
        {
            id => "DP",
            number => "1",
            type => "Integer",
            description => "Read depth",
        }
        , "caller format field");

    is($header->filters->{BAD}, "Badness", "BAD filter");
    is($header->filters->{PASS}, "Passed all filters", "PASS filter");
    is($header->filters->{REALLY_BAD}, "Oh no", "REALLY_BAD filter");
};

subtest "sample_index" => sub {
    my $header = $pkg->create(lines => \@lines);
    ok($header, "Parsed header");

    is($header->index_for_sample_name("S1"), 0, "index for S1 is correct");
    is($header->index_for_sample_name("S2"), 1, "index for S1 is correct");
    is($header->index_for_sample_name("S3"), 2, "index for S1 is correct");
};

subtest "sample_index_not_found" => sub {
    my $header = $pkg->create(lines => \@lines);
    ok($header, "Parsed header");
    eval {$header->index_for_sample_name("S0");};
    ok($@, "Sample index not found is an error");
};

subtest "to_string" => sub {
    my $header = $pkg->create(lines => \@lines);
    ok($header, "Parsed header");

    # Order of elements in the header isn't guaranteed. Let's sort so we can compare.
    my $expected = join("\n", sort split("\n", $header_txt));
    my $actual = join("\n", sort split("\n", $header->to_string));

    my $diff = Genome::Sys->diff_text_vs_text($actual, $expected);
    ok(!$diff, "to_string is as expected") || diag($diff);
};

subtest "add filter" => sub {
    my $header = $pkg->create(lines => \@lines);
    ok($header, "Parsed header");

    is_deeply([sort keys %{$header->filters}], ["BAD", "PASS", "REALLY_BAD"], "Got expected filter names");
    $header->add_filter(id => "TEST", description => "Test filter");
    is_deeply([sort keys %{$header->filters}], ["BAD", "PASS", "REALLY_BAD", "TEST"], "TEST filter was added");
    is($header->filters->{TEST}, "Test filter", "TEST filter has correct description");

    my $expected_new_line = '##FILTER=<ID=TEST,Description="Test filter">';
    my $expected = join("\n", sort(split("\n", $header_txt), $expected_new_line));
    my $actual = join("\n", sort split("\n", $header->to_string));

    my $diff = Genome::Sys->diff_text_vs_text($actual, $expected);
    ok(!$diff, "New filter shows up in string output") || diag($diff);
};

subtest "add format type" => sub {
    my $header = $pkg->create(lines => \@lines);
    ok($header, "Parsed header");

    my @should_throw = (
        # missing data
        {},
        { id => "x", },
        { id => "x", type => "Integer", },
        { type => "Integer", number => 1, },
        { id => "x", type => "Integer", number => 1, },
        { id => "x", type => "Integer", description => "x", },
        { type => "Integer", number => 1, description => "x", },

        # bad data
        { id => "x", type => "Bad", number => 1, description => "x", },
        { id => "x", type => "String", number => "several", description => "x", },

        # duplicate data
        { id => "GT", type => "String", number => 1, description => "Genotype" },
        { id => "DP", type => "Integer", number => 1, description => "Read depth" },
    );

    for my $ex (@should_throw) {
        eval {
            $header->add_format_type(%$ex);
        };
        ok($@, "Exception thrown as expected") or diag sprintf("Expected %s to throw", Dumper($ex));
    }

    $header->add_format_type(id => "FT", type => "String", number => ".", description => "Filters");

    is_deeply($header->format_types->{FT},
        {
            id => "FT",
            number => ".",
            type => "String",
            description => "Filters",
        }
        , "added FT format field");

    eval {
        $header->add_format_type(id => "FT", type => "String", number => ".", description => "Filters");
    };
    ok($@, "Adding FT twice is an error");

    $header->add_format_type(id => "FT", type => "String", number => ".", description => "Changed", skip_if_exists => 1);
    is($header->format_types->{FT}{description}, "Filters", "adding FT with skip if exists does not change value");


    my $expected_new_line = '##FORMAT=<ID=FT,Number=.,Type=String,Description="Filters">';
    my $expected = join("\n", sort(split("\n", $header_txt), $expected_new_line));
    my $actual = join("\n", sort split("\n", $header->to_string));

    my $diff = Genome::Sys->diff_text_vs_text($actual, $expected);
    ok(!$diff, "to_string is as expected") || diag($diff);
};



done_testing();
