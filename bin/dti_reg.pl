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
use File::Slurp qw(read_file);
use File::Find::Rule;
use File::Basename qw(basename);
use Data::Dump qw(dump);
use File::Copy::Recursive qw(dirmove);

use NEURO4 qw(get_subjects check_subj load_project print_help get_list check_or_make cut_shit);

my $study;
my $cfile="";
my $debug=0;
my $old=0;
my $chop=0;
my $timeout='8:0:0';
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-old/) {$old=1;}
    if (/^-chop/) {$old=1; $chop=1;}
    if (/^-time/) {$timeout = shift; chomp($timeout)}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/dti_reg.hlp'; exit;}
}
$study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/dti_reg.hlp'; exit;}

my %std = load_project($study);

my $subj_dir = $ENV{'SUBJECTS_DIR'};
my $pipe_dir = $ENV{'PIPEDIR'};
# Redirect ouput to logfile (do it only when everything is fine)
my $logfile = "$std{'DATA'}/.debug_dti_register.log";
open STDOUT, ">$logfile" or die "Can't redirect stdout";
open STDERR, ">&STDOUT" or die "Can't dup stdout";
$debug ? open DBG, ">$logfile" :0;

#Run this script ONLY on "Detritus"
#or change the paths to the correct ones

my $w_dir=$std{'WORKING'};
my $bids_dir=$std{'BIDS'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $data_dir=$std{'DATA'};

my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

print "Collecting needed files\n";

my @dtis = cut_shit($db, $data_dir."/".$cfile);

foreach my $subject (sort @dtis){
	if($subject){
		my %nifti = check_subj($std{'DATA'},$subject);
		if($nifti{'T1w'} && $nifti{'dwi'}){
			my $order;
			if($old){
				if($chop){
					$order = $pipe_dir."/bin/dti_proc_x.sh ".$study." ".$subject." ".$nifti{'dwi'}." ".$nifti{'T1w'}." ".$w_dir;
				}else{
					$order = $pipe_dir."/bin/dti_proc_deprecated.sh ".$subject." ".$nifti{'dwi'}." ".$w_dir;
				}
			}else{
				if($nifti{'dwi_sbref'}){
       		                	$order = $pipe_dir."/bin/dti_proc_epi.sh ".$study." ".$subject." ".$nifti{'dwi'}." ".$nifti{'dwi_sbref'}." ".$nifti{'T1w'}." ".$w_dir;
       		                }else{
                                	$order = $pipe_dir."/bin/dti_proc_uncorr.sh ".$study." ".$subject." ".$nifti{'dwi'}." ".$nifti{'T1w'}." ".$w_dir;
                        	}
			}
			my $orderfile = $outdir.'/'.$subject.'dti_orders.sh';
			open ORD, ">$orderfile";
			print ORD '#!/bin/bash'."\n";
			print ORD '#SBATCH -J dti_reg_'.$study."\n";
			print ORD '#SBATCH --time='.$timeout."\n"; #si no ha terminado en X horas matalo
			print ORD '#SBATCH -c 4'."\n";
			print ORD '#SBATCH --mem-per-cpu=4G'."\n";
			print ORD '#SBATCH --mail-type=FAIL,STAGE_OUT'."\n"; #no quieres que te mande email de todo
			print ORD '#SBATCH -o '.$outdir.'/dti_reg-slurm-%j'."\n";
			unless($old){ print ORD '#SBATCH --gres=gpu:1'."\n"; }
			print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
			unless($old){ print ORD '#SBATCH -p cuda'."\n"; }else{print ORD '#SBATCH -p fast'."\n";}
			print ORD "srun $order\n";
			close ORD;
			system("sbatch $orderfile");
			$debug ? print DBG "$order\n" :0;
		}
	}
}
$debug ? close DBG:0;  
my $orderfile = $outdir.'/dti_reg_end.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J dti_reg_'.$study."\n";
print ORD '#SBATCH --mail-type=END'."\n"; #email cuando termine
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -o '.$outdir.'/dti_reg_end-%j'."\n";
print ORD "srun $ENV{'PIPEDIR'}/bin/make_dti_report.pl $study\n"; 
close ORD;
my $order = 'sbatch --dependency=singleton '.$orderfile;
exec($order);

