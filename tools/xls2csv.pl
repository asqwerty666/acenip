#!/usr/bin/perl

use strict;
use warnings;
use Spreadsheet::XLSX;
my $ifile=shift;
my $excel = Spreadsheet::XLSX -> new ($ifile);
foreach my $sheet (@{$excel -> {Worksheet}}) {
	$sheet -> {MaxRow} ||= $sheet -> {MinRow};
	foreach my $row ($sheet -> {MinRow} .. $sheet -> {MaxRow}) {
		$sheet -> {MaxCol} ||= $sheet -> {MinCol};
		foreach my $col ($sheet -> {MinCol} ..  $sheet -> {MaxCol}) {
			my $cell = $sheet -> {Cells} [$row] [$col];
			print($cell -> {Val});
			print ",";
		}
		print "\n";
	 }
	 print "\n";
}
