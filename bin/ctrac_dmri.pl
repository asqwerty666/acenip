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

# Este script crea el archivo dmri.rc para ejecutar TRACULA en un proyecto
# (Ver: https://detritus.fundacioace.com/wiki/doku.php?id=neuroimagen:tracula
# y https://surfer.nmr.mgh.harvard.edu/fswiki/trac-all#Processingstepoptions)
# No es parte de los pasos de TRACULA sino que se ejecuta antes para crear 
# la configuracion

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
my $echospacing = 0.5;
my $epifactor = 100;

@ARGV = ("-h") unless @ARGV;

while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-echosp/) { $echospacing = shift; chomp($echospacing);}
    if (/^-epif/) { $epifactor = shift; chomp($epifactor)}
    if (/^-h$/) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_dmri.hlp'; exit;}
}
# Leo y preparo la configuracion del proyecto
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_dmri.hlp'; exit;}
my %std = load_project($study);
my $w_dir = $std{'WORKING'};
my $data_dir = $std{'DATA'};
my $bids_dir = $std{'BIDS'};
my $fsdir = $ENV{'SUBJECTS_DIR'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);
################ Variables generales ###############
### En algun momento deberian poder definirse ######
### desde input. Pero por ahora voy a ponerlas #####
### fijas. #########################################
my @jobs;
my $dob_line = 'set dob0 = 2';
my $pedir_line = 'AP PA ';
my @subjects = cut_shit($db, $data_dir."/".$cfile);
my $dmrirc = $data_dir.'/dmri.rc';
my $b0vec = $ENV{'PIPEDIR'}.'/lib/b0.bvec';
my $b0val = $ENV{'PIPEDIR'}.'/lib/b0.bval';
unless (-e $dmrirc && -r $dmrirc){
	my $subjlist = 'set subjlist = (  ';
	my $dmclist = 'set dcmlist = ( ';
	my $bveclist = 'set bveclist = ( ';
	my $bavllist = 'set bvallist = ( ';;
	my $pedir = 'set pedir = ( ';
	foreach my $subject (@subjects) {
		my %nifti = check_subj($std{'DATA'},$subject);
		if($nifti{'dwi'} and $nifti{'dwi_sbref'}){
			$subjlist.=$study.'_'.$subject.' '.$study.'_'.$subject.' ';
			$dmclist.=$nifti{'dwi'}.' '.$nifti{'dwi_sbref'}.' ';
			(my $bvec = $nifti{'dwi'}) =~ s/nii\.gz$/bvec/;
			(my $bval = $nifti{'dwi'}) =~ s/nii\.gz$/bval/;
			$bveclist.=$bvec.' '.$b0vec.' ';
			$bavllist.=$bval.' '.$b0val.' ';
			$pedir.=$pedir_line; 
			unless ( -e $ENV{'SUBJECTS_DIR'}.'/'.$study.'_'.$subject.'/mri/ThalamicNuclei.v12.T1.FSvoxelSpace.mgz' ){
				my %ptask = ( 'filename' => $outdir.'/segthalamus_'.$subject.'.sh',
					'job_name' => 'segthalamus_'.$study,
					'cpus' => 2,
					'time' => '2:0:0',
					'mem_per_cpu' => '4G',
					'partition' => 'fast',
					'output' => $outdir.'/segthalamus',
					'command' => 'segmentThalamicNuclei.sh '.$study.'_'.$subject,
				);
				my $jobid = send2slurm(\%ptask);
				push @jobs, $jobid;
			}
		}
	}
	$subjlist.=')';
	$dmclist.=')';
	$bveclist.=')';
	$bavllist.=')';
	$pedir.=')';
	open CIF, ">$dmrirc" or die "Couldnt open dmrirc file for writing\n";
	print CIF "$dob_line\n$subjlist\n$dmclist\n$bveclist\n$bavllist\n$pedir\n";
	print CIF 'set echospacing = '."$echospacing\n".'set epifactor = '."$epifactor\n";
	close CIF;
}else{
	die "There is a previous dmrirc file\nYou should delete it and try again\n";
}
if (scalar(@jobs)) {
	my $ljobs = join(',',@jobs);
	$ljobs = 'afterok:'.$ljobs;
	my %hey = (
		'filename' => $outdir.'/segthalamus_end.sh',
		'job_name' => 'segthalamus_'.$study,
		'output' => $outdir.'/segthalamus_end',
		'dependency' => $ljobs,
	);
	send2slurm(\%hey);
}
