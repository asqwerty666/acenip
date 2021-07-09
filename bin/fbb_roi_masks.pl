#!/usr/bin/perl
# Copyright 2019 O. Sotolongo <asqwerty@gmail.com>
#
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
use NEURO4 qw(print_help load_project check_or_make cut_shit centiloid_fbb);
use FSMetrics qw(fs_fbb_rois);
my %ROI_Comps = fs_fbb_rois();
my $cfile="";
my $wcb = 0;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-wcb/) { $wcb = shift;}
}
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/pet_metrics.hlp'; exit;}
my %std = load_project($study);
my $w_dir=$std{'WORKING'};
my $data_dir=$std{'DATA'};
my $db = $data_dir.'/'.$study.'_pet.csv';
my $ofile;
if ($wcb) {
        $ofile = $data_dir."/".$study."_fbb_fs_suvr_rois_wcb.csv";
}else{
        $ofile = $data_dir."/".$study."_fbb_fs_suvr_rois_gmcb.csv";
}

my @subjects = cut_shit($db, $data_dir."/".$cfile);

open OF, ">$ofile";
print OF "Subject";
foreach my  $npf (sort keys %ROI_Comps){
	print OF ";$npf";
#	if($npf eq "Global"){ 
#		print OF ";Centiloid";
#	}
}
print OF "\n";
foreach my $subject (sort @subjects){
	my $pet = $w_dir.'/'.$subject.'_fbb.nii.gz';
	my $mdir = $w_dir.'/tmp_'.$subject.'_masks';
	my $cereb = $mdir.'/cerebellum.nii.gz';
	if (-e $cereb && -f $cereb) {
		print OF "$subject";
		my $order = "fslstats ".$pet." -k ".$mdir."/cerebellum -M";
		(my $norm) = qx/$order/;
		chomp($norm);
		foreach my  $npf (sort keys %ROI_Comps){
			$order = "fslstats ".$pet." -k ".$mdir."/".$npf." -M";
			print "$order\n";
			(my $mean) = qx/$order/;
			$mean /= $norm;
			print OF ";$mean";
#			if($npf eq "Global"){
#				my $cl = centiloid_fbb($mean);
#				print OF ";$cl";		
#			}
		}
	print OF "\n";
	}
}
close OF;
