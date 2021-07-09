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

use strict; use warnings;
 
use File::Find::Rule;
use NEURO4 qw(print_help load_project check_or_make cut_shit);
use FSMetrics qw(fs_fbb_rois);
use Data::Dump qw(dump);
use File::Remove 'remove';
use File::Basename qw(basename);
use Parallel::ForkManager;

my %ROI_Comps = fs_fbb_rois();

my $reduce = 0;
my $cfile = "";
my $wcut = 0;
my $wcb = 0; # Use Whole Cerebellum as ref ROI?
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile); $wcut = 1;}
    if (/^-wcb/) { $wcb = 1;}
    if (/^-h$/) { print_help $ENV{'PIPEDIR'}.'/doc/pet_metrics.hlp'; exit;}
}
 
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/pet_metrics.hlp'; exit;}
my %std = load_project($study);
my $w_dir=$std{'WORKING'};
my $data_dir=$std{'DATA'};
my $db = $std{'DATA'}.'/'.$study.'_pet.csv';
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

# Redirect ouput to logfile (do it only when everything is fine)
my $debug = "$data_dir/.debug_pet_fs_metrics.log";
open STDOUT, ">$debug" or die "Can't redirect stdout";
open STDERR, ">&STDOUT" or die "Can't dup stdout";
my $ofile;
if ($wcb) {
	$ofile = $data_dir."/".$study."_fbb_fs_suvr_rois_wcb.csv";
}else{
	$ofile = $data_dir."/".$study."_fbb_fs_suvr_rois_gmcb.csv";
}

our @subjects = cut_shit($db, $data_dir."/".$cfile);

foreach my $subject (@subjects){
	my $reg_fbb = $w_dir.'/'.$subject.'_fbb.nii.gz';
	if(-e $reg_fbb && -f $reg_fbb){
		my $order = $ENV{'PIPEDIR'}."/bin/fbb_make_roi_masks.pl ".$study." ".$subject." ".$w_dir." ".$wcb;
		my $orderfile = $outdir.'/'.$subject.'_fbb_roi.sh';
		open ORD, ">$orderfile";
		print ORD '#!/bin/bash'."\n";
		print ORD '#SBATCH -J fbb_mroi_'.$study."\n";
		print ORD '#SBATCH --time=4:0:0'."\n"; #si no ha terminado en X horas matalo
		print ORD '#SBATCH -c 4'."\n"; # para limitar el numero de launches
		print ORD '#SBATCH --mem-per-cpu=4G'."\n";
		print ORD '#SBATCH --mail-type=FAIL,TIME_LIMIT,STAGE_OUT'."\n"; #no quieres que te mande email de todo
		print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
		print ORD '#SBATCH -o '.$outdir.'/fbb_mroi-'.$subject.'-%j'."\n";
		print ORD "srun $order\n";
		close ORD;
		system("sbatch $orderfile");
	}
}
my $order = $ENV{'PIPEDIR'}."/bin/fbb_roi_masks.pl ".$study." ".$wcb." ".($wcut?"-cut $cfile":"");
my $orderfile = $outdir.'/fbb_masks.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J fbb_mroi_'.$study."\n";
print ORD '#SBATCH --time=4:0:0'."\n"; #si no ha terminado en X horas matalo
print ORD '#SBATCH --mail-type=FAIL,END'."\n"; #email cuando termine o falle
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -o '.$outdir.'/fbb_roi_masks-%j'."\n";
print ORD "srun $order\n";
close ORD;
my $xorder = 'sbatch --dependency=singleton'.' '.$orderfile;
exec($xorder);

