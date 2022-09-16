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
# This script is where we manage to launch fmriprep singularity image
# for each fMRI image in a project. The FS segmentation should be done
# prior to do this or you will get a lot of errors.

use strict; use warnings;
 
use File::Find::Rule;
use NEURO4 qw(print_help load_project cut_shit check_subj check_or_make);
use Data::Dump qw(dump);
use File::Remove 'remove';
use File::Basename qw(basename);
use File::Copy::Recursive qw(dircopy);
use SLURMACE qw(send2slurm);
my $fslic = '/nas/usr/local/opt/freesurfer/.license';
my $fmriprep_version = '1.5.8';
my $fmriprep_simg = '/usr/local/bin/fmriprep-latest.simg';
my $cfile="";
my $fs = 0;
my $st = 0;
@ARGV = ("-h") unless @ARGV;

while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-fs/) { $fs = 1};
    if (/^-st/) {$st = 1};
    if (/^-h$/) { print_help $ENV{'PIPEDIR'}.'/doc/dfmriprep.hlp'; exit;}
}
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/dfmriprep.hlp'; exit;}
my %std = load_project($study);
my $w_dir = $std{'WORKING'};
my $data_dir = $std{'DATA'};
my $bids_dir = $std{'BIDS'};
my $fsdir = $ENV{'SUBJECTS_DIR'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $fmriout_dir = $data_dir.'/fmriprep_out';
my $fmriwork_dir = $data_dir.'/fmriprep_work';
my $fssubsdir = $fmriout_dir.'/freesurfer';
my $nofscall; 
my $noslicetiming;
if($st){
	$noslicetiming = "";
}else{
	$noslicetiming = "--ignore slicetiming";
}
check_or_make($fmriout_dir);
check_or_make($fmriwork_dir);
check_or_make($fssubsdir);
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

my @subjects = cut_shit($db, $data_dir."/".$cfile);
my %ptask = ('job_name' => 'fmriprep_'.$study,
	'time' => '72:0:0',
	'mailtype' => 'FAIL,TIME_LIMIT,STAGE_OUT',
	'cpus' => 16,
	'mem_per_cpu' => '4G',
	'partition' => 'fast',
);
foreach my $subject (@subjects) {
	my %nifti = check_subj($std{'DATA'},$subject);
	if($nifti{'func'}){
		#if($fs){
			my $fssd = $fssubsdir.'/sub-'.$subject;
			my $rfssd = $fsdir.'/'.$study.'_'.$subject;
			check_or_make($fssd);
			dircopy($rfssd,$fssd);
		#}
		$ptask{'filename'} = $outdir.'/'.$subject.'_fmriprep.sh';
		$ptask{'job_name'} = 'fmriprep_'.$study;
		$ptask{'output'} = $outdir.'/fmriprep';
		$ptask{'command'} = 'singularity run --cleanenv -B /nas:/nas '.$fmriprep_simg.' '.$bids_dir.' '.$fmriout_dir.' participant --participant-label '.$subject.' '.$noslicetiming.' --skip_bids_validation --fs-license-file '.$fslic.' --nthreads 16 --omp-nthreads 8 --mem-mb 30000 --output-spaces T1w MNI152Lin fsnative --use-aroma -w '.$fmriwork_dir;
		send2slurm(\%ptask);
	}
}
my %final = ( 'filename' => $outdir.'/fmriprep_end.sh',
	'job_name' => 'fmriprep_'.$study,
	'output' => $outdir.'/fmriprep_end',
	'dependency' => 'singleton',
);
send2slurm(\%final);
