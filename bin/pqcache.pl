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
# El objetivo de este script es preparar el proyecto para hacer un SBM.
# O dicho de otra manera, el Freesurfer Group Analysis (FSGA) se hace mas comodamente
# si se antes se ejecuta el recon-all con la opcion -qcache 
#
# Segun https://surfer.nmr.mgh.harvard.edu/fswiki/FsTutorial/GroupAnalysis:
# When you run recon-all with the -qcache option, recon-all will resample data 
# onto the average subject (called fsaverage) and smooth it at various FWHM 
# (full-width/half-max) values, usually 0, 5, 10, 15, 20, and 25mm. This can 
# speed later processing. 
# 
# Asi que aqui paralelizamos el recon-all -qcache y vamos a suponer que ya hemos
# ejecutado la segmentacion, o la hemos bajado de XNAT con xnat_getfs.pl o similar. 

use strict; use warnings;
use File::Basename qw(basename);
use Data::Dump qw(dump);
use SLURM qw(send2slurm);
use NEURO4 qw(populate check_subj load_project print_help check_or_make get_subjects get_list);

my $cfile;

@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/recon.hlp'; exit;}
}
# Hacemos lo usual, leemos el proyecto, configuramos el workspace, etc
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/recon.hlp'; exit;}
my $debug = 1;
#my $stage = "-autorecon-all";

my %std = load_project($study);
my $data_dir=$std{'DATA'};
my $mri_db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $bids_path = $std{'DATA'}.'/bids';
#open debug file
my $logfile = "$std{'DATA'}/.debug.controlled.log";
$debug ? open DBG, ">$logfile" :0;
#open slurm file
#my $orderfile = "$std{'DATA'}/mri_orders.sh";
#my $conffile = "$std{'DATA'}/mri_orders.conf";
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
my %ptask = ( 'job_name' => 'fs_qcache_'.$study,
	'time' => '48:0:0',
	'cpus' => 4,
	'mem_per_cpu' => '4G',
	'mailtype' => 'FAIL,TIME_LIMIT,STAGE_OUT',
	'partition' => 'fast',
);
foreach my $pkey (sort @plist){
	my $subj = $study."_".$pkey;
	my $subj_dir = $ENV{'SUBJECTS_DIR'}.'/'.$subj;
	if( -e $subj_dir && -d $subj_dir){
		$ptask{'command'} = "recon-all -subjid ".$subj." -qcache";
		$ptask{'filename'}  = $outdir.'/'.$subj.'fs_qcache.sh';
		$ptask{'output'} = $outdir.'/fs_qcache-slurm-'.$subj;
		send2slurm(\%ptask);
		sleep(2);
	}
}

$debug ? close DBG:0;	
my %final = ( 'filename' => $outdir.'/fs_qcache_end.sh',
	'job_name' => 'fs_qcache_'.$study,
	'output' => $outdir.'/fs_recon_end',
	'dependency' => 'singleton',
);
send2slurm(\%final);
