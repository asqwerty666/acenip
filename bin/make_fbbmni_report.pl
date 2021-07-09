#!/usr/bin/perl

# Copyright 2019 O. Sotolongo <asqwerty@gmail.com>

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

use NEURO4 qw(load_project print_help);

@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/make_fbb_report.hlp'; exit;}
}
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/make_pet_report.hlp'; exit;}

my %std = load_project($study);

my $w_dir=$std{'WORKING'};
my $d_dir=$std{'DATA'};

# Redirect ouput to logfile (do it only when everything is fine)
my $debug = "$d_dir/.debug_report.log";
open STDOUT, ">$debug" or die "Can't redirect stdout";
open STDERR, ">&STDOUT" or die "Can't dup stdout";

my $order = "slicesdir -o ";
my @names = find(file => 'name' => "*_fbb_mni.nii.gz", in => $w_dir);
foreach my $name (sort @names){
	my $mni = '/usr/local/fsl/data/standard/MNI152_T1_2mm.nii.gz';
	$order .= $name.' '.$mni." ";
}
chdir $w_dir;
print "$order\n";
system($order);
dirmove('slicesdir', 'fbbmnis');
