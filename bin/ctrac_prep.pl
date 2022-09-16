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

# Este es el primero de los pasos para ejecutar TRACULA en un proyecto
# (Ver: https://detritus.fundacioace.com/wiki/doku.php?id=neuroimagen:tracula
# y https://surfer.nmr.mgh.harvard.edu/fswiki/trac-all#Processingstepoptions)
# En total son cuatro pasos,
# - ctrac_prep.pl
# - ctrac_bedp.pl
# - ctrac_path.pl 
# - ctrac_stat.pl
#
# Aqui lo que hacemos es ejecutar trac-all -prep para que no haga nada pero escriba 
# en un archivo las ordenes que queremos enviar a SLURM

use strict; use warnings;

use File::Find::Rule;
use NEURO4 qw(print_help load_project cut_shit check_subj check_or_make);
use SLURMACE qw(send2slurm);
use Data::Dump qw(dump);
use File::Remove 'remove';
use File::Basename qw(basename);
use File::Copy::Recursive qw(dircopy);

my $cfile="";
my $cpus = 8;

@ARGV = ("-h") unless @ARGV;

while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-h$/) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_prep.hlp'; exit;}
}
# Leo y preparo la configuracion del proyecto
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_prep.hlp'; exit;}
my %std = load_project($study);
my $w_dir = $std{'WORKING'};
my $data_dir = $std{'DATA'};
my $bids_dir = $std{'BIDS'};
my $fsdir = $ENV{'SUBJECTS_DIR'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

my @subjects = cut_shit($db, $data_dir."/".$cfile);
my $dmrirc = $data_dir.'/dmri.rc';
my $tmp_orders = 'trac_step1.txt';
# y ahora, si no esta el archivo dmri.rc, lo creo, 
# a partir de los datos del proyecto
unless (-e $dmrirc && -r $dmrirc){
        die "No dmri.rc file found\nProvide one or run ctrac_dmri.pl to generate it\n";
}
# Ahora ya tengo todo el input que necesito y lo que hago es generar las ordenes
my $pre_order = 'trac-all -prep -c '.$dmrirc.' -jobs '.$tmp_orders;
system($pre_order);
# Y ya tengo la lista de ordenes a ejecutar,
# vamos alla!
open CORD, "<$tmp_orders" or die "Could find orders file";
# Un momento que voy a definir el hash para pasar la ejecucion a slurm
my %ptask;
$ptask{'job_name'} = 'trac_prep_'.$study;
$ptask{'cpus'} = $cpus;
$ptask{'time'} = '72:0:0';
$ptask{'mem_per_cpu'} = '4G';
$ptask{'partition'} = 'fast';
while (<CORD>){
	#ahora hay que enviar cada orden de este archivo al cluster
	(my $subj) = /subjects\/$study\_(.*)\/scripts\/dmrirc/;
	#print "$subj\n";
	$ptask{'filename'} = $outdir.'/'.$subj.'_trac_prep.sh';
	$ptask{'output'} = $outdir.'/trac_prep';
	$ptask{'command'} = 'export MY_MORPHS_DO_NOT_CONFORM_DEAL_WITH_IT=1'."\n".$_;
	send2slurm(\%ptask);	
}
close CORD;
# y aviso cuando todo haya acabado
my %final;
$final{'filename'} = $outdir.'/trac_prep_end.sh';
$final{'job_name'} = 'trac_prep_'.$study;
$final{'output'} = $outdir.'/trac_prep_end';
$final{'mailtype'} = 'END';
$final{'dependency'} = 'singleton';
send2slurm(\%final);
