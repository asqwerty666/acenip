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
use NEURO4 qw(print_help load_project cut_shit check_subj check_or_make);
use Data::Dump qw(dump);
use File::Remove 'remove';
use File::Basename qw(basename);
use File::Copy::Recursive qw(dircopy);

my $fslic = '/nas/usr/local/opt/freesurfer/.license';
my $fmriprep_version = '1.5.8';
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

foreach my $subject (@subjects) {
	my %nifti = check_subj($std{'DATA'},$subject);
	if($nifti{'func'}){
		#if($fs){
			my $fssd = $fssubsdir.'/sub-'.$subject;
			my $rfssd = $fsdir.'/'.$study.'_'.$subject;
			check_or_make($fssd);
			dircopy($rfssd,$fssd);
		#}
		my $orderfile = $outdir.'/'.$subject.'_fmriprep.sh';
		open ORD, ">$orderfile";
		print ORD '#!/bin/bash'."\n";
		print ORD '#SBATCH -J fmriprep_'.$study."\n";
		print ORD '#SBATCH --time=72:0:0'."\n"; #si no ha terminado en X horas matalo
		print ORD '#SBATCH --mail-type=FAIL,TIME_LIMIT,STAGE_OUT'."\n"; #no quieres que te mande email de todo
		print ORD '#SBATCH -o '.$outdir.'/fmriprep-%j'."\n";
		print ORD '#SBATCH -c 16'."\n";
		print ORD '#SBATCH --mem-per-cpu=4G'."\n";
		print ORD '#SBATCH -p fast'."\n";
		print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
		print ORD 'singularity run --cleanenv -B /nas:/nas /usr/local/bin/fmriprep-latest.simg '.$bids_dir.' '.$fmriout_dir.' participant --participant-label '.$subject.' '.$noslicetiming.' --skip_bids_validation --fs-license-file '.$fslic.' --nthreads 16 --omp-nthreads 8 --mem-mb 30000 --output-spaces T1w MNI152Lin fsnative --use-aroma -w '.$fmriwork_dir;
		print ORD "\n";
		close ORD;
		system("sbatch $orderfile");
		#sleep(20);
	}
}
my $orderfile = $outdir.'/fmriprep_end.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J fmriprep_'.$study."\n";
print ORD '#SBATCH --mail-type=END'."\n"; #email cuando termine
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -p fast'."\n";
print ORD '#SBATCH -o '.$outdir.'/fmriprep_end-%j'."\n";
print ORD ":\n";
close ORD;
my $order = 'sbatch --dependency=singleton '.$orderfile;
exec($order);
