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

# Este es el segundo paso de TRACULA. Es equivalente a un bedpostx de FSL
# (Ver: https://detritus.fundacioace.com/wiki/doku.php?id=neuroimagen:tracula
# y https://surfer.nmr.mgh.harvard.edu/fswiki/trac-all#Processingstepoptions)
# En total son cuatro pasos,
# - ctrac_prep.pl
# - ctrac_bedp.pl
# - ctrac_path.pl 
# - ctrac_stat.pl
#
# Aqui lo que hacemos es ejecutar trac-all -bedp para que no haga nada 
# pero escriba en tres archivos distintos las ordenes que queremos enviar 
# a SLURM. Hay que tener en cuenta las dependencias entre las ordenes y 
# enviar los grupos segun el archivo a que pertenezcan
use strict; use warnings;

use File::Find::Rule;
use NEURO4 qw(print_help load_project cut_shit check_subj check_or_make);
use SLURM qw(send2slurm);
use Data::Dump qw(dump);
use File::Remove 'remove';
use File::Basename qw(basename);
use File::Copy::Recursive qw(dircopy);

my $cfile="";

@ARGV = ("-h") unless @ARGV;

while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-h$/) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_bedp.hlp'; exit;}
}
my $study = shift;
#Leo el input y config del proyecto
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_bedp.hlp'; exit;}
my %std = load_project($study);
my $w_dir = $std{'WORKING'};
my $data_dir = $std{'DATA'};
my $bids_dir = $std{'BIDS'};
my $fsdir = $ENV{'SUBJECTS_DIR'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

my @subjects = cut_shit($db, $data_dir."/".$cfile);
my $tmp_orders = 'trac_step2.txt';
# y ahora, si no esta el archivo dmri.rc, lo creo, 
# a partir de los datos del proyecto
my $dmrirc = $data_dir.'/dmri.rc';
unless (-e $dmrirc && -r $dmrirc){
	die "No dmri.rc file found\nProvide one or run ctrac_dmri.pl to generate it\n";
}
# Ahora se generan las ordenes
my $pre_order = 'trac-all -bedp -c '.$dmrirc.' -jobs '.$tmp_orders;
system($pre_order);
#run pre-bedp first
(my $pre_tmp_orders = $tmp_orders) =~ s/\.txt/\.pre\.txt/;
# defino el hash para el pre-bedp
my %prebedp;
$prebedp{'job_name'} = 'trac_pre_bedp_'.$study;
$prebedp{'cpus'} = 8;
$prebedp{'time'} = '8:0:0';
$prebedp{'mem_per_cpu'} = '4G';
$prebedp{'partition'} = 'fast';
open CORD, "<$pre_tmp_orders" or die "Could find orders file";
while (<CORD>){
	# Ejecuto en el cluster cada orden del archivo
	(my $subj) = /subjects\/$study\_(.*)\/dmri/;
	my $cpath = $fsdir.'/'.$study.'_'.$subj.'/dmri.bedpostX/logs/monitor';
	system('mkdir -p '.$cpath);
	$prebedp{'filename'} = $outdir.'/'.$subj.'_trac_pre_bedp.sh';
	$prebedp{'output'} = $outdir.'/trac_prep';
	$prebedp{'command'} = $_;
	send2slurm(\%prebedp);
}
close CORD;
my %preend;
$preend{'job_name'} = 'trac_pre_bedp_'.$study;
$preend{'filename'} = $outdir.'/trac_pre_bedp_end.sh';
$preend{'mailtype'} = 'END';
$preend{'output'} = $outdir.'/trac_pre_bedp_end';
$preend{'dependency'} = 'singleton';
# Cuando todos los pre-bedp han terminado, envio un email y capturo
# el id del proceso que lo envia
my $jobid = send2slurm(\%preend);
#run bedp now
#ahora defino el hash para los bedp
my %bedp;
$bedp{'job_name'} = 'trac_bedp_'.$study;
$bedp{'time'} = '12:0:0';
$bedp{'cpus'} = 8;
$bedp{'mem_per_cpu'} = '4G';
$bedp{'partition'} = 'fast';
# lanzar estos depende de los anteriores!
$bedp{'dependency'} = 'afterok:'.$jobid;
my $count = 0;
open CORD, "<$tmp_orders" or die "Could find orders file";
while (<CORD>){
	(my $subj) = /subjects\/$study\_(.*)\/dmri/;
	$bedp{'filename'} = $outdir.'/'.$subj.'_'.$count.'_trac_bedp.sh';
        $bedp{'output'} = $outdir.'/trac_bedp';
	$bedp{'command'} = $_;
	send2slurm(\%bedp);
	$count++;
}
close CORD;
# cuando acaben estos, mando email
my %bpend;
$bpend{'filename'} = $outdir.'/trac_bedp_end.sh';
$bpend{'job_name'} = 'trac_bedp_'.$study;
$bpend{'mailtype'} = 'END'; #email cuando termine
$bpend{'output'} = $outdir.'/trac_bedp_end';
$bpend{'dependency'} = 'singleton';
# y capturo el jobid 
$jobid = send2slurm(\%bpend);
#and post.bedp later
(my $post_tmp_orders = $tmp_orders) =~ s/\.txt/\.post\.txt/;
my %postbedp;
$postbedp{'job_name'} = 'trac_post_bedp_'.$study;
$postbedp{'time'} = '12:0:0';
$postbedp{'cpus'} = 8;
$postbedp{'partition'} = 'fast';
$postbedp{'mem_per_cpu'} = '4G';
$postbedp{'dependency'} = 'afterok:'.$jobid;
open CORD, "<$post_tmp_orders" or die "Could find orders file";
while (<CORD>){
        (my $subj) = /subjects\/$study\_(.*)\/dmri/;
        $postbedp{'filename'} = $outdir.'/'.$subj.'_trac_post_bedp.sh';
	$postbedp{'output'} = $outdir.'/trac_post';
	$postbedp{'command'} = $_;
	send2slurm(\%postbedp);	
}
close CORD;
my %postend;
$postend{'filename'} = $outdir.'/trac_post_bedp_end.sh';
$postend{'job_name'} = 'trac_post_bedp_'.$study;
$postend{'mailtype'}='END'; #email cuando termine
$postend{'output'} = $outdir.'/trac_post_bedp_end';
$postend{'dependency'} = 'singleton';
send2slurm(\%postend);
