#!/usr/bin/perl
# Copyright 2019 O. Sotolongo <asqwerty@gmail.com>
use strict; use warnings;
 
use File::Find::Rule;
use NEURO4 qw(print_help load_project check_or_make centiloid_fbb cut_shit);
use Data::Dump qw(dump);
use File::Remove 'remove';
use File::Basename qw(basename);

my $ref_roi =  "voi_WhlCbl_2mm.nii";
my $ctx_roi = "voi_ctx_2mm.nii";

my $roi_paths = $ENV{'PIPEDIR'}.'/lib/Centiloid_Std_VOI/nifti/2mm/';
my $withstd = 0;
my $cfile="";

@ARGV = ("-h") unless @ARGV;

while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
}
 
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/pet_metrics.hlp'; exit;}
my %std = load_project($study);
my $w_dir=$std{'WORKING'};
my $data_dir=$std{'DATA'};
my $db = $data_dir.'/'.$study.'_pet.csv';
our @subjects = cut_shit($db, $data_dir."/".$cfile);

my $ofile = $data_dir."/".$study."_fbb_cl.csv";

open OF, ">$ofile";
print OF "Subject; SUVR; Centilod";
print OF "\n";

foreach my $subject (sort @subjects){
        my $fbb = $w_dir.'/'.$subject.'_fbb.nii.gz';
        my $struct = $w_dir.'/'.$subject.'_struc.nii.gz';
        if (-e $fbb && -e $struct){
		# Apply masks to FBB
		my $roi_mask = $roi_paths.$ctx_roi;
		my $order = "fslstats ".$w_dir."/".$subject."_fbb_mni -k ".$roi_mask." -M";
		print "$order\n";
		my $ctx = qx/$order/;
		$roi_mask = $roi_paths.$ref_roi;
		$order = "fslstats ".$w_dir."/".$subject."_fbb_mni -k ".$roi_mask." -M";
		print "$order\n";
		my $norm = qx/$order/;
		if ($norm > 0) {
			my $mean = $ctx/$norm;
			print OF "$subject";
       		        print OF ";$mean";
              		print OF ";", centiloid_fbb($mean);
	                print OF "\n";
		} 	
	}
}
close OF;
