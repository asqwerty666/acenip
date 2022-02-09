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

use File::Find::Rule;
use NEURO4 qw(print_help load_project cut_shit shit_done);
use Data::Dump qw(dump);
use File::Basename qw(basename);

my $with_sd = 0;
my $threshold = 0.5;
my $net_path;
my $cfile = "";
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-thr/) {$threshold = shift;}
    if (/^-path/) {$net_path = shift;}
    if (/^-sd/) { $with_sd = 1;}
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/dti_metrics_tracks.hlp'; exit;}
}

my $study = shift;
$net_path = "out" unless $net_path;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/dti_metrics_tracs.hlp'; exit;}
my %std = load_project($study);

my $w_dir=$std{'WORKING'};
my $data_dir=$std{'DATA'};
my $db = $data_dir.'/'.$study.'_mri.csv';
print "Collecting needed files\n";

my @dtis = cut_shit($db, $data_dir.'/'.$cfile);

my $ofile = $data_dir."/".$study."_dti_".$net_path.".csv";
open OF, ">$ofile";
print OF "Subject";
if($with_sd){
	print OF ";$net_path","_FA_Mean;","$net_path","_FA_STD",";$net_path","_MD_Mean;","$net_path","_MD_STD";
}else{
	print OF ";$net_path","_FA",";$net_path","_MD";
}
print OF "\n";

foreach my $subject (sort @dtis){
	my $img_path = $w_dir.'/'.$subject.'_probtrack_'.$net_path.'/fdt_paths.nii.gz';
	if(-e $img_path && -f $img_path){
		print OF "$subject";
		my $dti_fa = $w_dir.'/'.$subject.'_dti_FA.nii.gz';
		my $dti_md = $w_dir.'/'.$subject.'_dti_MD.nii.gz';	
		my $order = $ENV{'PIPEDIR'}.'/bin/track2mask.sh '.$img_path.' '.$threshold;
		print "$order\n";
		system($order);
		my $mask_path = $w_dir.'/'.$subject.'_probtrack_'.$net_path.'/fdt_paths_mask.nii.gz'; 
		$order = "fslstats ".$dti_fa." -k ".$mask_path." -M -S";
		print "$order\n";
		(my $mean, my $std) = map{/(\d+\.\d*)\s*(\d+\.\d*)/} qx/$order/;
		if($with_sd){
			print OF ";$mean",";$std";
		}else{
			print OF ";$mean";
		}
		$order = "fslstats ".$dti_md." -k ".$mask_path." -M -S";
		print "$order\n";
		($mean, $std) = map{/(\d+\.\d*)\s*(\d+\.\d*)/} qx/$order/;
		if($with_sd){
			print OF ";$mean",";$std";
		}else{
			print OF ";$mean";
		}
		print OF "\n";
	}
}
close OF;

my $zfile=$std{DATA}."/".$study."_dti_".$net_path."_results.tgz";
system("tar czf $zfile $ofile");
shit_done basename($ENV{_}), $study, $zfile;
