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
foreach my $pkey (sort @plist){
	my $subj = $study."_".$pkey;
	my $subj_dir = $ENV{'SUBJECTS_DIR'}.'/'.$subj;
	if( -e $subj_dir && -d $subj_dir){
		my $order = "recon-all -subjid ".$subj." -qcache";
		my $orderfile = $outdir.'/'.$subj.'fs_qcache.sh';
		open ORD, ">$orderfile";
		print ORD '#!/bin/bash'."\n";
		print ORD '#SBATCH -J fs_qcache_'.$study."\n";
		print ORD '#SBATCH --time=48:0:0'."\n"; #si no ha terminado en X horas matalo
		print ORD '#SBATCH --mail-type=FAIL,TIME_LIMIT,STAGE_OUT'."\n"; #no quieres que te mande email de todo
		print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
		print ORD '#SBATCH -p fast'."\n";
		print ORD '#SBATCH -c 4'."\n";
		print ORD '#SBATCH --mem-per-cpu=4G'."\n";
		print ORD '#SBATCH -o '.$outdir.'/fs_qcache-slurm-'.$subj.'-%j'."\n";
		print ORD "srun $order\n";
		close ORD;
		system("sbatch $orderfile");
		sleep(2);
	}
}

$debug ? close DBG:0;	
my $orderfile = $outdir.'/fs_qcache_end.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J fs_qcache_'.$study."\n";
print ORD '#SBATCH --mail-type=END'."\n"; #email cuando termine
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -o '.$outdir.'/fs_recon_end-%j'."\n";
print ORD ":\n";
close ORD;
my $order = 'sbatch --dependency=singleton '.$orderfile;
exec($order);
