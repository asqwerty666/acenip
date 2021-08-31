#!/usr/bin/perl

# Copyright 2021 O. Sotolongo <asqwerty@gmail.com>

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
use NEURO4 qw(get_subjects check_fs_subj load_project print_help shit_done check_or_make);
#use FSMetrics qw(fs_file_metrics);
use File::Basename qw(basename);
use Data::Dump qw(dump);

my $hsf_i_data = ".hippoSfVolumes-T1.v10.txt";
my $legacy = 0;
my @hemis = ("lh", "rh");
# print help if called without arguments
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-old/) { $legacy = 1;}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/hsf_metrics.hlp'; exit;}
}

my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/hsf_metrics.hlp'; exit;}
if ($legacy) {
	my $hsf_i_data = ".hippoSfVolumes-T1.v10.txt";
}else{
	my $hsf_i_data = ".hippoSfVolumes-T1.v21.txt";
}
my %std = load_project($study);
my $db = $std{DATA}.'/'.$study.'_mri.csv';
my $fsout = $std{DATA}.'/'.$study.'_hsf_metrics.csv';
my @plist = get_subjects($db);
my $subj_dir = $ENV{'SUBJECTS_DIR'};
#my %stats = fs_file_metrics();

my @fspnames;
foreach my $pkey (@plist){
	my $subj = $study."_".$pkey;
	if(check_fs_subj($subj)){
		push @fspnames, $subj;
	}
}
my %metrics;
my %headers;
foreach my $subject (@fspnames){
	foreach my $hemi (@hemis){
		my $hsfdp = $subj_dir.'/'.$subject.'/mri/'.$hemi.$hsf_i_data;
		if (-e $hsfdp){
			open IDF, "<$hsfdp";
			while(<IDF>){
				my ($hs_k, $hs_v) = /(\S+)\s+(\S+)/;
				$metrics{$subject}{$hemi}{$hs_k} = $hs_v;
				$headers{$hs_k} = 1;
			}
			close IDF;
		}
	}
}
open ODF, ">$fsout";
print ODF "Subject";
foreach my $hemi (sort @hemis){
	foreach my $tag (sort keys %headers){
		print ODF ",$hemi.$tag";
	}
}
foreach my $tag (sort keys %headers){
	print ODF ",whole.$tag";
}
print ODF "\n";
foreach my $subject (sort @fspnames){
	my $hsfdp = $subj_dir.'/'.$subject.'/mri/lh'.$hsf_i_data;
	if(-e $hsfdp){
		print ODF "$subject";
		foreach my $hemi (sort @hemis){
			foreach my $tag (sort keys %headers){
				print ODF ",$metrics{$subject}{$hemi}{$tag}";
			}
		}
		foreach my $tag (sort keys %headers){
			my $whole = $metrics{$subject}{'lh'}{$tag}+$metrics{$subject}{'rh'}{$tag};
			print ODF ",$whole";
		}
		print ODF "\n";
	}
}
close ODF;

my $zfile=$std{DATA}."/".$study."_hsf_results.tgz";
system("tar czf $zfile $fsout");
shit_done basename($ENV{_}), $study, $zfile;

