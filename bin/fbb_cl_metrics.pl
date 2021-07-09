#!/usr/bin/perl
# Copyright 2019 O. Sotolongo <asqwerty@gmail.com>
use strict; use warnings;
 
use File::Find::Rule;
use NEURO4 qw(print_help load_project check_or_make centiloid_fbb cut_shit);
use Data::Dump qw(dump);
use File::Remove 'remove';
use File::Basename qw(basename);

my $wcut = 0;
my $cfile="";

@ARGV = ("-h") unless @ARGV;

while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile); $wcut = 1;}
    if (/^-h$/) { print_help $ENV{'PIPEDIR'}.'/doc/pet_metrics.hlp'; exit;}
}
 
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/pet_metrics.hlp'; exit;}
my %std = load_project($study);
my $w_dir=$std{'WORKING'};
my $data_dir=$std{'DATA'};
my $db = $data_dir.'/'.$study.'_pet.csv';
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);
our @subjects = cut_shit($db, $data_dir."/".$cfile);

my $ofile = $data_dir."/".$study."_fbb_cl.csv";

foreach my $subj (sort @subjects){
	#Making sbatch scripts
	# Get FBB image into MNI space
	my $fbb = $w_dir.'/'.$subj.'_fbb.nii.gz';
	my $struct = $w_dir.'/'.$subj.'_struc.nii.gz';
	if (-e $fbb && -e $struct){
		my $order = $ENV{'PIPEDIR'}."/bin/fbb2std.sh ".$subj." ".$w_dir;
		my $orderfile = $outdir.'/'.$subj.'_fbb_reg.sh';
		open ORD, ">$orderfile";
		print ORD '#!/bin/bash'."\n";
		print ORD '#SBATCH -J fbb_metrics_'.$study."\n";
		print ORD '#SBATCH --time=4:0:0'."\n"; #si no ha terminado en X horas matalo
		print ORD '#SBATCH -c 8'."\n"; #para limitar el numero de ejecuciones por maquina
		print ORD '#SBATCH --mem-per-cpu=4G'."\n";
		print ORD '#SBATCH --mail-type=FAIL,TIME_LIMIT,STAGE_OUT'."\n"; #no quieres que te mande email de todo
		print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
		print ORD '#SBATCH -o '.$outdir.'/fbb2std-'.$subj.'-%j'."\n";
		print ORD "srun $order\n";
		close ORD;
		sleep 1;
		system("sbatch $orderfile");
	}
}
my $order = $ENV{'PIPEDIR'}."/bin/fbb_cl_masks.pl ".$study." ".($wcut?"-cut $cfile":"");
my $orderfile = $outdir.'/fbb_masks.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J fbb_metrics_'.$study."\n";
print ORD '#SBATCH --time=24:0:0'."\n"; #si no ha terminado en X horas matalo
print ORD '#SBATCH --mail-type=FAIL,END'."\n"; #email cuando termine o falle
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -o '.$outdir.'/fbbmasks-%j'."\n";
print ORD "srun $order\n";
close ORD;
my $xorder = 'sbatch --dependency=singleton'.' '.$orderfile;
exec($xorder);
