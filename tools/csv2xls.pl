#!/usr/bin/perl

use strict;
use warnings;
use Text::CSV qw( csv );
use Spreadsheet::Write;

my $ifile = shift;
die "Please, give an input CSV file\n" unless $ifile;
(my $ofile = $ifile) =~ s/.csv$/.xls/;
my $info = csv (in => $ifile);
my $workbook = Spreadsheet::Write->new(file => $ofile, sheet => 'DATA');
for my $i (0 .. $#{$info}) {
	my $row = $info->[$i];
	$workbook->addrow($row);
}
$workbook->close();

