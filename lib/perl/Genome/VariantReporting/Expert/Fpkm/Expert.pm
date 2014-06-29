package Genome::VariantReporting::Expert::Fpkm::Expert;

use strict;
use warnings FATAL => 'all';
use Genome;

class Genome::VariantReporting::Expert::Fpkm::Expert {
    is => 'Genome::VariantReporting::Component::Expert',
};

sub name {
    'fpkm';
}


1;
