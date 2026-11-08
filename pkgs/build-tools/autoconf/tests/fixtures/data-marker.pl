BEGIN {
  open my $marker, '>>', $ENV{'AUTOTOOLS_DATA_LOG'} or die $!;
  print {$marker} "selected\n";
}
