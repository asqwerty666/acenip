#!/usr/bin/perl

# Copyright 2022 O. Sotolongo <asqwerty@gmail.com>

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
my $icbm = 0;

@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-a/) {$icbm = 1;}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/recon.hlp'; exit;}
}

my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/recon.hlp'; exit;}
my $debug = 1;
my $stage = "-autorecon-all";
my $pgs = '/nas/usr/local/opt/singularity/pgs.simg';
my %std = load_project($study);
my $data_dir=$std{'DATA'};
my $mri_db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $bids_path = $std{'DATA'}.'/bids';
#open debug file
my $logfile = "$std{'DATA'}/.debug.controlled.log";
$debug ? open DBG, ">$logfile" :0;
#open slurm file
my $orderfile = "$std{'DATA'}/wmh_orders.sh";
my $conffile = "$std{'DATA'}/wmh_orders.conf";
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);
my $wdir = $std{'WORKING'};
my $minput = $wdir.'/input';
my $input_dir = $wdir.'/input/pre';
check_or_make($input_dir);
my $output_dir = $wdir.'/output';
check_or_make($output_dir);
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
my %ptask;
$ptask{'time'} = '48:0:0';
$ptask{'job_name'} = 'wmh_'.$study;
$ptask{'cpus'} = 64;
$ptask{'mem_per_cpu'} = '4G';
foreach my $pkey (sort @plist){
	my $subj = $study."_".$pkey;
	my %nifti = check_subj($std{'DATA'},$pkey);
	if($nifti{'T1w'} and $nifti{'T2w'}){
		my $order;
		my $t1char = ${$nifti{'T1w'}}[0];
		my $t1base = basename($t1char);
		my $t2base = basename($nifti{'T2w'}); 
		$ptask{'command'} = 'cp '.$t1char.' '.$input_dir.'/'."\n";
		$ptask{'command'}.= 'antsRegistrationSyNQuick.sh -d 3 -t a -f '.$t1char.' -m '.$nifti{'T2w'}.' -o '.$input_dir.'/'.$pkey.'t2tot1_'."\n";
		$ptask{'command'}.= 'antsApplyTransforms -d 3 -i '.$nifti{'T2w'}.' -r '.$t1char.' -t '.$input_dir.'/'.$pkey.'t2tot1_0GenericAffine.mat -o '.$input_dir.'/'.$t2base."\n";
		if($icbm) {
			$ptask{'command'}.= 'antsRegistrationSyNQuick.sh -t s -d 3 -f '.$t1char.' -m '.$ENV{'FSLDIR'}.'/data/standard/MNI152_T1_1mm.nii.gz -o '.$input_dir.'/'.$pkey.'_mni_t1_warp'."\n";
			$ptask{'command'}.= 'antsApplyTransforms -d 3 -i '.$ENV{'FSLDIR'}.'/data/atlases/JHU/JHU-ICBM-labels-1mm.nii.gz -r '.$t1char.' -t '.$input_dir.'/'.$pkey.'_mni_t1_warp1Warp.nii.gz -t '.$input_dir.'/'.$pkey.'_mni_t1_warp0GenericAffine.mat -n GenericLabel -o '.$output_dir.'/'.$pkey.'_JHU_labels.nii.gz'."\n";
			$ptask{'command'}.= 'antsApplyTransforms -d 3 -i '.$ENV{'FSLDIR'}.'/data/atlases/JHU/JHU-ICBM-tracts-maxprob-thr25-1mm.nii.gz -r '.$t1char.' -t '.$input_dir.'/'.$pkey.'_mni_t1_warp1Warp.nii.gz -t '.$input_dir.'/'.$pkey.'_mni_t1_warp0GenericAffine.mat -n GenericLabel -o '.$output_dir.'/'.$pkey.'_JHU_tracts.nii.gz'."\n";
		}
		$ptask{'command'}.= 'singularity run --cleanenv -B /nas:/nas -B '.$output_dir.':/output -B '.$minput.':/input '.$pgs.' sh /WMHs_segmentation_PGS.sh '.$t1base.' '.$t2base.' '.$pkey.'_WMH.nii.gz'."\n";
		$ptask{'filename'} = $outdir.'/'.$subj.'wmh_orders.sh';
		$ptask{'output'} = $outdir.'/wmh-slurm-'.$subj;
		my $jobid = send2slurm(\%ptask);
#		sleep(10);
#
	}
}

$debug ? close DBG:0;	
my %warn;
$warn{'filename'} = $outdir.'/wmh_end.sh';
$warn{'job_name'} = 'wmh_'.$study;
$warn{'mailtype'} = 'END'; #email cuando termine
$warn{'output'} =  $outdir.'/wmh_end';
$warn{'dependency'} = 'singleton';
send2slurm(\%warn);

