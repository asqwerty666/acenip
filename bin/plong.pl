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
# Aqui la intencion es hacer un analisis longitudinal con Freesurfer
# Ver https://detritus.fundacioace.com/wiki/doku.php?id=neuroimagen:fs_long_analysis
#
# Se supone que para proceder he de tener un archivo relacionando los 
# distintos puntos del analisis. En principio lo he probado con dos puntos 
# pero el algoritmo esta escrito para N puntos. Solo habra que tener un
# archivo con un formato similar a este,
#
# flong_subject;SubjID_v0;SubjID_v2
# flong_0001;facehbi_0001;f2cehbi_0001
# flong_0002;facehbi_0002;f2cehbi_0002
# flong_0003;facehbi_0003;f2cehbi_0003
#
# Entonces deberia crear el proyecto longitudinal de la forma usual,
#
# make_proj lfacehbi /nas/corachan/facehbi
#
# y ejecutar este script 
#
# plong.pl -i flong.csv lfacehbi
#

use strict; use warnings;
use File::Basename qw(basename);
use Data::Dump qw(dump);
use SLURMACE qw(send2slurm);
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
# Debo tener el archivo longitudinal y el nombre del proyecto definidos
unless ($ifile && $study) { print_help $ENV{'PIPEDIR'}.'/doc/longitudinal.hlp'; exit;}
my $debug = 1;
my %lsubjects;
# Aqui lo que hago es meter en un HoA los puntos longitudinales
open ILF, "<$ifile" or die "Could not open input data file\n";
while(<ILF>){
	my @long_list = split /;/, $_;
	my $lindex = $long_list[0];
	splice(@long_list,0,1);
	$lsubjects{$lindex} = [ @long_list ];
}
close ILF;
# y cargo los datos del proyecto
my %std = load_project($study);
my $data_dir=$std{'DATA'};
#open debug file
my $logfile = "$std{'DATA'}/.debug.controlled.log";
$debug ? open DBG, ">$logfile" :0;
#open slurm file
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

my %ptask = ('job_name' => 'fs_long_'.$study,
	'time' => '48:0:0',
	'mailtype' => 'FAIL,TIME_LIMIT,STAGE_OUT',
	'partition' => 'fast',
	'cpus' => 4,
	'mem_per_cpu' => '4G',	
);
foreach my $lsubject (sort keys %lsubjects){
	my $sub_check_dir = $ENV{'SUBJECTS_DIR'}.'/'.$lsubjects{$lsubject}[0];
	if( -e $sub_check_dir && -d $sub_check_dir){
		my $subol = join ' -tp ', @{$lsubjects{$lsubject}};
		chomp $subol;
		$ptask{'command'} = "recon-all -base ".$lsubject." -tp ".$subol." -all";
		$ptask{'filename'} = $outdir.'/'.$lsubject.'_fs_long_base.sh';
		$ptask{'output'} = $outdir.'/fs_long_base-slurm-'.$lsubject;
		$ptask{'dependency'} = '';
		my $jobid = send2slurm(\%ptask);
		foreach my $ind_subject (sort @{$lsubjects{$lsubject}}){
			chomp $ind_subject;
			$ptask{'command'} = "recon-all -long ".$ind_subject." ".$lsubject." -all";
			$ptask{'filename'} = $outdir.'/'.$lsubject.'_'.$ind_subject.'_fs_long_base.sh';
			$ptask{'output'} = $outdir.'/fs_long_ind-slurm-'.$lsubject.'_'.$ind_subject;
			$ptask{'dependency'} = "afterok:$jobid";
			send2slurm(\%ptask);
		}
		sleep(2);
	}
}

$debug ? close DBG:0;	
my %final = ('filename' => $outdir.'/fs_long_end.sh',
	'job_name' => 'fs_long_'.$study,
	'output' => $outdir.'/fs_long_end',
	'dependency' => 'singleton',
);
send2slurm(\%final);
