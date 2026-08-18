use strict;
use warnings;

my %seen;
my @words = grep { !$seen{$_}++ } qw(tvp nix tvp preserves nix);
print join(" ", @words);
