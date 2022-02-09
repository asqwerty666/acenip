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
# Este es el tercer paso (pathway reconstruction) en la ejecucion de TRACULA
# (Ver: https://detritus.fundacioace.com/wiki/doku.php?id=neuroimagen:tracula
# y https://surfer.nmr.mgh.harvard.edu/fswiki/trac-all#Processingstepoptions)
# En total son cuatro pasos,
# - ctrac_prep.pl
# - ctrac_bedp.pl
# - ctrac_path.pl
# - ctrac_stat.pl
#
# Aqui se ejecuta trac-all -path, configurado apra que escriba las ordenes a ejecutar 
# en un archivo y no haga nada mas. Luego tomamos estas ordenes y las paralelizamos en
# el cluster.
use strict; use warnings;

use File::Find::Rule;
use NEURO4 qw(print_help load_project cut_shit check_subj check_or_make);
use Data::Dump qw(dump);
use SLURM qw(send2slurm);
use File::Remove 'remove';
use File::Basename qw(basename);
use File::Copy::Recursive qw(dircopy);

my $cfile="";

@ARGV = ("-h") unless @ARGV;

while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-h$/) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_path.hlp'; exit;}
}
my $study = shift;
# Se lee el proyecto (as usual)
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_path.hlp'; exit;}
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
my $tmp_orders = 'trac_step3.txt';
# si no existe el archivo dmri.rc lo creo a partir de
# los datos del proyecto
unless (-e $dmrirc && -r $dmrirc){
        die "No dmri.rc file found\nProvide one or run ctrac_dmri.pl to generate it\n";
}
# Y genero las ordenes a ejecutar
my $pre_order = 'trac-all -path -c '.$dmrirc.' -jobs '.$tmp_orders;
system($pre_order);
open CORD, "<$tmp_orders" or die "Could find orders file";
# Opciones comunes del call
my %ptask; 
$ptask{'job_name'} = 'trac_path_'.$study;
$ptask{'cpus'} = 8;
$ptask{'time'} = '72:0:0';
$ptask{'mem_per_cpu'} = '4G';
$ptask{'partition'} = 'fast';
while (<CORD>){
	#genero una orden por cada linea
	(my $subj) = /subjects\/$study\_(.*)\/scripts\/dmrirc/;
	$ptask{'filename'} = $outdir.'/'.$subj.'_trac_path.sh';
	$ptask{'output'} = $outdir.'/trac_path';
	$ptask{'command'} = $_;
	send2slurm(\%ptask);
}
close CORD;
# email de aviso de finalizacion
my %final;
$final{'filename'} = $outdir.'/trac_path_end.sh';
$final{'job_name'} = 'trac_path_'.$study;
$final{'output'} = $outdir.'/trac_path_end';
$final{'mailtype'} = 'END';
$final{'dependency'} = 'singleton';
send2slurm(\%final);
