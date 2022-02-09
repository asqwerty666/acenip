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
use strict; use warnings;
use File::Slurp qw(read_file);
use File::Find::Rule;
use File::Basename qw(basename);
use Data::Dump qw(dump);
use File::Copy::Recursive qw(dirmove);

use NEURO4 qw(load_project print_help cut_shit);

my $cfile ="";
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_report.hlp'; exit;}
}
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_report.hlp'; exit;}
my %std = load_project($study);
my $w_dir=$std{'WORKING'};
my $data_dir=$std{'DATA'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $subjsdir = $ENV{'SUBJECTS_DIR'};
my $reference = '/usr/local/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz';
my @subjects = cut_shit($db, $data_dir."/".$cfile);

# Redirect ouput to logfile (do it only when everything is fine)
my $debug = "$data_dir/.debug_report.log";
open STDOUT, ">$debug" or die "Can't redirect stdout";
open STDERR, ">&STDOUT" or die "Can't dup stdout";

my $order = "slicesdir -o ";

foreach my $subject (sort @subjects){
	my $name = $subjsdir.'/'.$study.'_'.$subject.'/dmri/mni/dtifit_FA.bbr.nii.gz';
	$order .= $reference.' '.$name." ";
}
system($order);
print "$order\n";
dirmove('slicesdir', 'ctrac_report');

