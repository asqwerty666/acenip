#!/usr/bin/perl
# Formatear las fechas
# Copyright O.Sotolongo (asqwerty@gmail.com) 2020
use strict;
use warnings;
use NEURO4 qw(load_project inplace);

my $num_args = $#ARGV + 1;
die "Should supply input filename and project name\n" unless $num_args;
my $ifile = $ARGV[0];
my $study = $ARGV[1];
my $ofile;
($ofile = $ifile) =~ s/\.\w{2,4}$/_proper/;
$ofile =$ofile.'.csv';
my %std = load_project($study);
die 'Should supply project name\n' unless $study;
$ifile = inplace $std{'DATA'}, $ifile;
$ofile = inplace $std{'DATA'}, $ofile;

open IDF, "<$ifile";
open ODF, ">$ofile";
while (<IDF>) {
	if(/^.*,\d{8}$/) {
		my ($shit, $date) = /^(.*),(\d{8})$/;
		(my $cdate = $date) =~ s/(\d{4})(\d{2})(\d{2})/$3.$2.$1/;
		print ODF "$shit,$cdate\n";
	}else{
		print ODF;
	}
}
close ODF;
close IDF;
