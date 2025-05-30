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
use SLURMACE qw(send2slurm);
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
my $debug = 1;
my $stage = "-autorecon-all";

my %std = load_project($study);
my $data_dir=$std{'DATA'};
my $mri_db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $bids_path = $std{'DATA'}.'/bids';
#open debug file
my $logfile = "$std{'DATA'}/.debug.controlled.log";
$debug ? open DBG, ">$logfile" :0;
#open slurm file
my $orderfile = "$std{'DATA'}/mri_orders.sh";
my $conffile = "$std{'DATA'}/mri_orders.conf";
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

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
$ptask{'job_name'} = 'recon_'.$study;
$ptask{'cpus'} = 4;
$ptask{'mem_per_cpu'} = '4G';
foreach my $pkey (sort @plist){
	my $subj = $study."_".$pkey;
	my %nifti = check_subj($std{'DATA'},$pkey);
	if($nifti{'T1w'}){
		my $order;
#		if($nifti{'T2w'}){
#			$order = "recon-all ".$stage." -i ".$nifti{'T1w'}." -T2 ".$nifti{'T2w'}." -subjid ".$subj;
#		}else{
		my $t1char = join ' -i ', @{$nifti{'T1w'}}; 
		$ptask{'command'} = "recon-all ".$stage." -i ".$t1char." -subjid ".$subj;
		#$ptask{'command'} = "recon-all ".$stage." -i ".$nifti{'T1w'}." -subjid ".$subj;
#		}
		$ptask{'filename'} = $outdir.'/'.$subj.'fs_orders.sh';
		$ptask{'output'} = $outdir.'/fs_recon-slurm-'.$subj;
		send2slurm(\%ptask);
		sleep(10);
	}
}

$debug ? close DBG:0;	
my %warn;
$warn{'filename'} = $outdir.'/fs_recon_end.sh';
$warn{'job_name'} = 'recon_'.$study;
$warn{'mailtype'} = 'END'; #email cuando termine
$warn{'output'} =  $outdir.'/fs_recon_end';
$warn{'dependency'} = 'singleton';
send2slurm(\%warn);

