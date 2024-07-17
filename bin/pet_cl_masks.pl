#!/usr/bin/perl
# Copyright 2019 O. Sotolongo <asqwerty@gmail.com>
use strict; use warnings;
 
use File::Find::Rule;
use NEURO4 qw(print_help load_project check_or_make get_pair centiloid_fbb centiloid_flute centiloid_fbp cut_shit);
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
my $b_dir=$std{'BIDS'};
my $db = $data_dir.'/'.$study.'_pet.csv';
our @subjects = cut_shit($db, $data_dir."/".$cfile);

my $ofile = $data_dir."/".$study."_pet_cl.csv";
my %nhcs = get_pair($db);
open OF, ">$ofile";
print OF "Subject,SUVR,Centilod,Radiotracer";
print OF "\n";

foreach my $subject (sort @subjects){
        my $pet = $w_dir.'/'.$subject.'_pet_mni.nii.gz';
        my $struct = $w_dir.'/'.$subject.'_struc.nii.gz';
        if (-e $pet && -e $struct){
		# Find the original PET NIFTI
		my $kind;
		my @bids = find(file => 'name' => "*.nii.gz", in => $b_dir.'/sub-'.$subject.'/pet/');
		foreach my $bid (@bids){
			if ($bid =~ /.*_single_.*/){
				($kind = $bid) =~ s/.*_single_(.*)\.nii\.gz/$1/;
			}
		}
		# Apply masks to PET
		my $roi_mask = $roi_paths.$ctx_roi;
		my $order = "fslstats ".$w_dir."/".$subject."_pet_mni -k ".$roi_mask." -M";
		#print "$order\n";
		my $ctx = qx/$order/;
		$roi_mask = $roi_paths.$ref_roi;
		$order = "fslstats ".$w_dir."/".$subject."_pet_mni -k ".$roi_mask." -M";
		#print "$order\n";
		my $norm = qx/$order/;
		# Get CL
		if ($norm > 0) {
			my $mean = $ctx/$norm;
			print OF "$nhcs{$subject}";
       		        print OF ",$mean";
			if ($kind eq "fbb"){
              			print OF ",", centiloid_fbb($mean),",Florbetaben";
			}elsif ($kind eq "flute"){
				print OF ",", centiloid_flute($mean),",Flutemetanol";
			}elsif ($kind eq "fbp"){
				print OF ",", centiloid_fbp($mean),",Florbetapir";
			}else{
				print OF ",NA,NA";
			}
	                print OF "\n";
		} 	
	}
}
close OF;
