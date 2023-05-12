#!/usr/bin/perl

use strict;
use warnings;
use Spreadsheet::XLSX;
my $ifile=shift;
my $excel = Spreadsheet::XLSX -> new ($ifile);
foreach my $sheet (@{$excel -> {Worksheet}}) {
	$sheet -> {MaxRow} ||= $sheet -> {MinRow};
	foreach my $row ($sheet -> {MinRow} .. $sheet -> {MaxRow}) {
		my $wrow = '';
		$sheet -> {MaxCol} ||= $sheet -> {MinCol};
		foreach my $col ($sheet -> {MinCol} ..  $sheet -> {MaxCol}) {
			my $val = '';
			my $cell = $sheet -> {Cells} [$row] [$col];
			$val =  $cell -> {Val} if defined($cell -> {Val});
			$val =~ s/\n/ /g;
			$val =~ s/,/ /g;
			$val =~ tr/\015//d;
			$wrow .= $val.',';
		}
		$wrow =~ s/,$//;
		print "$wrow\n";
	 }
	 print "\n";
}
