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
use NEURO4 qw(print_help load_project check_or_make);
use FSMetrics qw(fs_fbb_rois);
my $study = shift;
my $subject = shift;
#my $pet = shift;
my $w_dir = shift;
my $wcb = shift;

my %ROI_Comps = fs_fbb_rois();

# Get aseg.mgz from FreeSurfer and translate to guy_aseg.nii.gz
my $order = $ENV{'PIPEDIR'}.'/bin/'."get_aseg.sh ".$study." ".$subject." ".$w_dir;
system($order);
# Make subject masks from aseg  
my $mdir = $w_dir.'/tmp_'.$subject.'_masks';
my $saseg = $w_dir.'/'.$subject.'_aseg';
my $pet = $w_dir.'/'.$subject.'_fbb';
# Make a temp directory to store masks
check_or_make($mdir);
my @cm;
# Make cerebellum mask if needed
if ($wcb) {
	@cm = (6, 7, 8, 45, 46, 47); # Whole Cerebellum
}else{
	@cm = (6, 8, 45, 47); # Just Cerebellum GM
}
foreach my $chunk (@cm){
	$order = $ENV{'FSLDIR'}.'/bin/'."fslmaths ".$saseg." -uthr ".$chunk." -thr ".$chunk." -div ".$chunk." ".$mdir."/cereb_".$chunk;
	#print "$order\n";
	system($order);
}
$order = $ENV{'FSLDIR'}.'/bin/'."fslmaths ".$mdir."/cereb_";
$order.= join " -add $mdir/cereb_", @cm;
$order.= " $mdir/cerebellum";
#print "$order\n";
system($order);

#  get subcortical shit
$order = $ENV{'PIPEDIR'}.'/bin/'."prepare_fs_labels.sh ".$study."_".$subject." ".$mdir;
print "$order\n";
system($order);
foreach my $npf (sort keys %ROI_Comps){
	for my $i (0 .. $#{$ROI_Comps{$npf}}){
		$order = $ENV{'PIPEDIR'}.'/bin/'."label2mask.sh ".$study."_".$subject." ".$mdir." ".$ROI_Comps{$npf}[$i];
		#print "$order\n";
		system($order);
	}
	$order = $ENV{'FSLDIR'}.'/bin/'."fslmaths ".$mdir."/";
	$order.= join " -add $mdir/",  @{$ROI_Comps{$npf}};
	$order.= " $mdir/$npf";
	#print "$order\n";
	system($order);
}			
