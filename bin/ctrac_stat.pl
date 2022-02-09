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

# Este es el ultimo de los pasos para ejecutar TRACULA en un proyecto
# (Ver: https://detritus.fundacioace.com/wiki/doku.php?id=neuroimagen:tracula
# y https://surfer.nmr.mgh.harvard.edu/fswiki/trac-all#Processingstepoptions)
# En total son cuatro pasos,
# - ctrac_prep.pl
# - ctrac_bedp.pl
# - ctrac_path.pl 
# - ctrac_stat.pl
#
# Aqui lo que hacemos es ejecutar trac-all -stat para que no haga nada pero escriba 
# en un archivo las ordenes que queremos enviar a SLURM
#
use strict; use warnings;

use File::Find::Rule;
use NEURO4 qw(print_help load_project cut_shit check_subj check_or_make);
use SLURM qw(send2slurm);
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
    if (/^-h$/) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_stat.hlp'; exit;}
}
# Leo y preparo la configuracion del proyecto
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_stat.hlp'; exit;}
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
my $tmp_orders = 'trac_step4.txt';
# y ahora, si no esta el archivo dmri.rc, lo creo, 
# a partir de los datos del proyecto
unless (-e $dmrirc && -r $dmrirc){
        die "No dmri.rc file found\nProvide one or run ctrac_dmri.pl to generate it\n";
}
# Ahora ya tengo todo el input que necesito y lo que hago es generar las ordenes
my $pre_order = 'trac-all -stat -c '.$dmrirc.' -jobs '.$tmp_orders;
system($pre_order);
# Y ya tengo la lista de ordenes a ejecutar,
# vamos alla!
my $count = 0;
open CORD, "<$tmp_orders" or die "Could find orders file";
my  %ptask = ('job_name' => 'trac_stat_'.$study,
	'cpus' => $cpus,
	'time' => '72:0:0',
	'mem_per_cpu' => '4G',
	'partition' => 'fast',
);
while (<CORD>){
	$ptask{'filename'} = $outdir.'/group_trac_stat_'.$count.'.sh';
	$ptask{'output'} = $outdir.'/trac_stat';
	$ptask{'command'} = $_;
	send2slurm(\%ptask);
	$count++;
}
close CORD;
# mando mail de aviso
my %final;
$final{'filename'} = $outdir.'/trac_stat_end.sh';
$final{'job_name'} = 'trac_stat_'.$study;
$final{'output'} = $outdir.'/trac_stat_end';
$final{'command'} = "mv $fsdir/stats $data_dir/stats";
$final{'mailtype'} = 'END';
$final{'dependency'} = 'singleton';
send2slurm(\%final);
