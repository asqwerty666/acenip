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

# Aqui lo que hacemos es mover el FBB a espacio MNI y aplicar 
# las mascaras definidas en Rowe et.al. para el calculo del
# SUVR y el Centiloide
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
my %ptask = ('job_name' => 'fbb_metrics_'.$study,
	'cpus' => 8,
	'mem_per_cpu' => '4G',
	'time' => '4:0:0',
	'mailtype' => 'FAIL,TIME_LIMIT,STAGE_OUT',
);

foreach my $subj (sort @subjects){
	#Making sbatch scripts
	# Get FBB image into MNI space
	my $fbb = $w_dir.'/'.$subj.'_fbb.nii.gz';
	my $struct = $w_dir.'/'.$subj.'_struc.nii.gz';
	if (-e $fbb && -e $struct){
		$ptask{'command'} = $ENV{'PIPEDIR'}."/bin/fbb2std.sh ".$subj." ".$w_dir;
		$ptask{'filename'} = $outdir.'/'.$subj.'_fbb_reg.sh';
		$ptask{'output'} = $outdir.'/fbb2std-'.$subj.'-%j';
		send2slurm(\%ptask);
		sleep 1;
	}
}
my %final = ('command' => $ENV{'PIPEDIR'}."/bin/fbb_cl_masks.pl ".$study." ".($wcut?"-cut $cfile":""),
	'output' => $outdir.'/fbb_masks.sh',
	'job_name' => 'fbb_metrics_'.$study,
	'time' => '24:0:0',
	'mailtype' => 'FAIL,END',
	'output' => $outdir.'/fbbmasks-%j',
	'dependency' => 'singleton',
);
send2slurm(\%final);
