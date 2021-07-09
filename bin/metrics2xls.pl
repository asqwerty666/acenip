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

my $idir;
my $guide;
my $ofile;
my $info_page;
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-i/) { $idir = shift; chomp($idir);}
    if (/^-g/) { $guide = shift; chomp($guide);}
    if (/^-o/) { $ofile = shift; chomp($ofile);}
    if (/^-s/) { $info_page = shift; chomp($info_page);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/metrics2xls.hlp'; exit;}
}
my $study = shift;
my %std = load_project($study);
die "Should supply project name\n" unless $study;
die "Should supply results directory\n" unless $idir;
die "Should supply guidance file\n" unless $guide;
$ofile = $idir.'.xls' unless $ofile;
$info_page = 'info_page.csv' unless $info_page;

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
foreach my $ifile (@ifiles){
        my $tmpf = 'tmp_'.$ifile;
        my $order = 'join -t, -1 2 -2 1 '.$guide.' '.$idir.'/'.$ifile.' > '.$tmpf;
        system($order);
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
