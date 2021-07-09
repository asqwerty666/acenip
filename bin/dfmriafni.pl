#!/usr/bin/perl

# Copyright 2020 O. Sotolongo <asqwerty@gmail.com>

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

my $template = $ENV{'PIPEDIR'}.'/lib/afni_proc_rest.template';
my $cfile="";

@ARGV = ("-h") unless @ARGV;

while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
#    if (/^-fs/) { $fs = 1};
    if (/^-h$/) { print_help $ENV{'PIPEDIR'}.'/doc/dfmriafni.hlp'; exit;}
}
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/dfmriafni.hlp'; exit;}
my %std = load_project($study);
my $w_dir = $std{'WORKING'};
my $data_dir = $std{'DATA'};
my $bids_dir = $std{'BIDS'};
my $fsdir = $ENV{'SUBJECTS_DIR'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $fmriout_dir = $data_dir.'/afni_out';

check_or_make($fmriout_dir);
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

my @subjects = cut_shit($db, $data_dir."/".$cfile);

foreach my $subject (@subjects) {
	my %nifti = check_subj($std{'DATA'},$subject);
	if($nifti{'func'}){
		chdir($outdir);
		my $creator = $outdir.'/afni_proc_'.$subject.'.py';
		open TPF, "<$template" or die "No template file\n";
		open CRF, ">$creator" or die "Could not create afni_proc\n";
		while(<TPF>){
			s/<project>/$study/;
			s/<subject>/sub-$subject/;
			s/<subject_mod>/sub_$subject/;
			s/<anat>/$nifti{'T1w'}/;
			s/<bold_rest>/$nifti{'func'}/;
			print CRF;
			print;
		}
		close CRF;
		close TPF;
		chmod 0755, $creator; 
		system($creator);
		my $orderfile = $outdir.'/'.$subject.'_fmriafni.sh';
		open ORD, ">$orderfile";
		print ORD '#!/bin/bash'."\n";
		print ORD '#SBATCH -J fmriafni_'.$study."\n";
		print ORD '#SBATCH --time=72:0:0'."\n"; #si no ha terminado en X horas matalo
		print ORD '#SBATCH --mail-type=FAIL,TIME_LIMIT,STAGE_OUT'."\n"; #no quieres que te mande email de todo
		print ORD '#SBATCH -o '.$outdir.'/fmriafni-%j'."\n";
		print ORD '#SBATCH -c 16'."\n";
		print ORD '#SBATCH --mem-per-cpu=4G'."\n";
		print ORD '#SBATCH -p fast'."\n";
		print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
		print ORD 'srun '.$outdir.'/proc.sub_'.$subject;
		close ORD;
		chdir($fmriout_dir);
		system("sbatch $orderfile");
	}
}
my $orderfile = $outdir.'/fmriafni_end.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J fmriafni_'.$study."\n";
print ORD '#SBATCH --mail-type=END'."\n"; #email cuando termine
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -p fast'."\n";
print ORD '#SBATCH -o '.$outdir.'/fmriprep_end-%j'."\n";
print ORD ":\n";
close ORD;
my $order = 'sbatch --dependency=singleton '.$orderfile;
exec($order);
