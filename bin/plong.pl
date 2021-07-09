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
use File::Basename qw(basename);
use Data::Dump qw(dump);

use NEURO4 qw(populate check_subj load_project print_help check_or_make get_subjects get_list);

my $ifile;

@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-i/) { $ifile = shift; chomp($ifile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/longitudinal.hlp'; exit;}
}

my $study = shift;
unless ($ifile && $study) { print_help $ENV{'PIPEDIR'}.'/doc/longitudinal.hlp'; exit;}
my $debug = 1;
my %lsubjects;

open ILF, "<$ifile" or die "Could not open input data file\n";
while(<ILF>){
	my @long_list = split /;/, $_;
	my $lindex = $long_list[0];
	splice(@long_list,0,1);
	$lsubjects{$lindex} = [ @long_list ];
}
close ILF;
my %std = load_project($study);
my $data_dir=$std{'DATA'};
#open debug file
my $logfile = "$std{'DATA'}/.debug.controlled.log";
$debug ? open DBG, ">$logfile" :0;
#open slurm file
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

foreach my $lsubject (sort keys %lsubjects){
	my $sub_check_dir = $ENV{'SUBJECTS_DIR'}.'/'.$lsubjects{$lsubject}[0];
	if( -e $sub_check_dir && -d $sub_check_dir){
		my $subol = join ' -tp ', @{$lsubjects{$lsubject}};
		chomp $subol;
		my $order = "recon-all -base ".$lsubject." -tp ".$subol." -all";
		my $orderfile = $outdir.'/'.$lsubject.'_fs_long_base.sh';
		open ORD, ">$orderfile";
		print ORD '#!/bin/bash'."\n";
		print ORD '#SBATCH -J fs_long_'.$study."\n";
		print ORD '#SBATCH --time=48:0:0'."\n"; #si no ha terminado en X horas matalo
		print ORD '#SBATCH --mail-type=FAIL,TIME_LIMIT,STAGE_OUT'."\n"; #no quieres que te mande email de todo
		print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
		print ORD '#SBATCH -p fast'."\n";
		print ORD '#SBATCH -c 4'."\n";
		print ORD '#SBATCH --mem-per-cpu=4G'."\n";
		print ORD '#SBATCH -o '.$outdir.'/fs_long_base-slurm-'.$lsubject.'-%j'."\n";
		print ORD "srun $order\n";
		close ORD;
		my $jobid = `sbatch $orderfile`;
		$jobid = ( split ' ', $jobid )[ -1 ];
		foreach my $ind_subject (sort @{$lsubjects{$lsubject}}){
			chomp $ind_subject;
			my $order = "recon-all -long ".$ind_subject." ".$lsubject." -all";
			my $orderfile = $outdir.'/'.$lsubject.'_'.$ind_subject.'_fs_long_base.sh';
			open IORD, ">$orderfile";
			print IORD '#!/bin/bash'."\n";
			print IORD '#SBATCH -J fs_long_'.$study."\n";
			print IORD '#SBATCH --time=48:0:0'."\n"; #si no ha terminado en X horas matalo
			print IORD '#SBATCH --mail-type=FAIL,TIME_LIMIT,STAGE_OUT'."\n"; #no quieres que te mande email de todo
			print IORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
			print IORD '#SBATCH -p fast'."\n";
			print IORD '#SBATCH -c 4'."\n";
			print IORD '#SBATCH --mem-per-cpu=4G'."\n";
			print IORD '#SBATCH -o '.$outdir.'/fs_long_ind-slurm-'.$lsubject.'_'.$ind_subject.'-%j'."\n";
			print IORD "srun $order\n";
			close IORD;
			system("sbatch --dependency=afterok:$jobid $orderfile");
		}
		sleep(2);
	}
}

$debug ? close DBG:0;	
my $orderfile = $outdir.'/fs_long_end.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J fs_long_'.$study."\n";
print ORD '#SBATCH --mail-type=END'."\n"; #email cuando termine
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -o '.$outdir.'/fs_long_end-%j'."\n";
print ORD ":\n";
close ORD;
my $order = 'sbatch --dependency=singleton '.$orderfile;
exec($order);
