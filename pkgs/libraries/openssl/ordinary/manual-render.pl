# POD is data: only this selected helper and the selected Perl's Pod::Man run.
use strict;
use warnings;
use Pod::Man;

my ($section, $name, $version, $date) = @ARGV;
die "invalid manual arguments\n" unless @ARGV == 4
    && $section =~ /^[1-9]$/ && $name =~ /^[A-Za-z0-9_+-]+$/
    && $version =~ /^[0-9][A-Za-z0-9.]+$/ && $date =~ /^\d{4}-\d{2}-\d{2}$/;
binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
my $parser = Pod::Man->new(section => $section, name => $name,
    center => 'OpenSSL', release => $version, date => $date,
    errors => 'die', utf8 => 1);
# Python already decoded the explicitly selected source encoding. Do not guess.
$parser->parse_characters(1);
$parser->parse_from_filehandle(\*STDIN, \*STDOUT);
die "POD rendering errors\n" if $parser->any_errata_seen;
