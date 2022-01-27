#!/usr/bin/perl

# Copyright 2018 O. Sotolongo <osotolongo@fundacioace.org>

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
use File::Basename qw(basename);
use SLURM qw(send2slurm);
use Data::Dump qw(dump);

use NEURO4 qw(populate check_subj load_project print_help check_or_make get_subjects get_list);

my $cfile;

@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/recon.hlp'; exit;}
}

my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/recon.hlp'; exit;}
my %std = load_project($study);
my $data_dir=$std{'DATA'};
my $mri_db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $wdir = $std{'WORKING'};
my $output_dir = $wdir.'/output';
my $fout = $std{DATA}.'/'.$study.'_wmh_metrics.csv';
#get subjects from database or file
my @plist;
my @iplist = get_subjects($mri_db);

if ($cfile){
	my @cuts = get_list($data_dir."/".$cfile);
	foreach my $cut (sort @cuts){
		if(grep {/$cut/} @iplist){
			push @plist, $cut;
		}
	}
}else{
	@plist = @iplist;
}
# go
my %metrics;
foreach my $subject (sort @plist){
	my $wmh_file = $output_dir.'/'.$subject.'_WMH.nii.gz';
	if (-e $wmh_file){
		my $order = 'fslstats '.$wmh_file.' -V';
		my ($volume) = qx/$order/;
		chomp $volume;
		$volume =~ s/\d+\s+(\.*)/$1/;
		#print "$subject,$volume\n";
		$metrics{$subject}{'WMH'} = $volume;
	}
}
open ODF, ">$fout";
print ODF "Subject,WMH\n";
foreach my $subject (sort keys %metrics){
	print ODF "$subject,$metrics{$subject}{'WMH'}\n";
}
close ODF;

