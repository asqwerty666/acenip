#!/usr/bin/perl

# Copyright 2020 O. Sotolongo <asqwerty@gmail.com>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
use strict;
use warnings;
use NEURO4 qw(load_project print_help inplace);
use Data::Dump qw(dump);
use Text::CSV qw( csv );
#use Excel::Writer::XLSX;
use Spreadsheet::Write;
use File::Copy;
use File::Temp qw( :mktemp);

my $idir;
my $guide;
my $ofile;
my $qcfile;
my $info_page;
my $outcsv = 0;
my $outsav = 0;
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-i/) { $idir = shift; chomp($idir);}
    if (/^-g/) { $guide = shift; chomp($guide);}
    if (/^-o/) { $ofile = shift; chomp($ofile);}
    if (/^-qc/) { $qcfile = shift; chomp($qcfile);}
    if (/^-s/) { $info_page = shift; chomp($info_page);}
    if (/^-xcsv/) {$outcsv = 1;}
    if (/^-xsav/) {$outsav = 1;}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/metrics2xls.hlp'; exit;}
}
my $study = shift;
my %std = load_project($study);
die "Should supply project name\n" unless $study;
die "Should supply results directory\n" unless $idir;
die "Should supply guidance file\n" unless $guide;
$ofile = $idir.'.xls' unless $ofile;
$info_page = 'info_page.csv' unless $info_page;
my $tmp_dir = $ENV{'TMPDIR'};
$idir = inplace $std{'DATA'}, $idir;
$info_page = inplace $std{'DATA'}, $info_page;
$guide = inplace $std{'DATA'}, $guide;
$ofile = inplace $std{'DATA'}, $ofile;

my $info = csv (in => $info_page);
$ofile =~ s/\.(\w*)?$/.xls/;
dump $ofile;
my $workbook = Spreadsheet::Write->new(file => $ofile, sheet => 'Info');
for my $i (0 .. $#{$info}) {
        my $row = $info->[$i];
        $workbook->addrow($row);
}
opendir (DIR, $idir);
my @ifiles = grep(/\.csv/, readdir(DIR));
close DIR;
my $odir;
if ($outcsv or $outsav) {
	($odir = $ofile) =~ s/\.xls$//;
	mkdir $odir unless -d $odir;
}
foreach my $ifile (@ifiles){
        my $tmpf = mktemp($tmp_dir.'/tmp_'.$ifile.'XXXXXX');
        my $order = 'join -t, -1 2 -2 1 '.$guide.' '.$idir.'/'.$ifile.' > '.$tmpf;
        system($order);
	if ($outcsv) {
		my $ocfile = $odir.'/'.$ifile;
		copy $tmpf, $ocfile;
	}
	if ($outsav){
		my $savfile = $odir.'/'.$ifile;
		$savfile =~ s/csv$/sav/;
		my $rscript = mktemp($tmp_dir.'/rtmpscript.XXXXX');
		open ORS, ">$rscript";
		print ORS 'library("haven")'."\n";
		print ORS 'setwd("'.$odir.'")'."\n";
		print ORS 'read.csv("'.$tmpf.'") -> w'."\n";
		print ORS 'write_sav(w,"'.$savfile.'")'."\n";
		close ORS;
		print "$rscript\n";
		system("Rscript $rscript");
	}
        my $idata = csv (in => $tmpf); # as array of array
        (my $shname = $ifile) =~ s/\.csv$//;
        $workbook->addsheet($shname);
        for my $i (0 .. $#{$idata}) {
                my $row = $idata->[$i];
		$workbook->addrow($row);
        }
        unlink $tmpf;
}
$workbook->close();
