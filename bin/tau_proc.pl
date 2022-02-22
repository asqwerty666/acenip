#!/usr/bin/perl

# Copyright 2021 O. Sotolongo <asqwerty@gmail.com>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

use strict; use warnings;
use Data::Dump qw(dump);
use File::Find::Rule;
use File::Copy::Recursive qw(dirmove);
use NEURO4 qw(check_pet check_subj load_project print_help check_or_make cut_shit);
use SLURM qw(send2slurm);
use FSMetrics qw(tau_rois);

my $cfile="";
my $time = '2:0:0';
my $style = "";
my $tracer = "";

@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-time/) {$time = shift; chomp($time);}
    if (/^-r/) {$style = shift; chomp($style);}
    if (/^-tracer/) {$tracer = shift; chomp($tracer);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/tau_reg.hlp'; exit;}
}
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/tau_reg.hlp'; exit;}
unless ($tracer) {die "Should supply -tracer RADIOTRACER\n"; }
my %std = load_project($study);

my $subj_dir = $ENV{'SUBJECTS_DIR'};

my $w_dir=$std{'WORKING'};
my $db = $std{'DATA'}.'/'.$study.'_pet.csv';
my $data_dir=$std{'DATA'};
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

print "Collecting needed files\n";
my @pets = cut_shit($db, $data_dir.'/'.$cfile);

#defino aqui las propiedades comunes de ejecucion
my %ptask;
$ptask{'job_name'} = 'tau_reg_'.$study;
$ptask{'cpus'} = 4;
$ptask{'time'} = $time;
my @ok_pets;
my @rois = tau_rois($style);
my @r_jobs;
my @p_jobs;
print "Running shit\n";
foreach my $subject (@pets){
        my %spet = check_pet($std{'DATA'},$subject,$tracer);
	my %smri = check_subj($std{'DATA'},$subject);
	if($spet{'tau'} && $smri{'T1w'}){
		push @ok_pets, $subject;
		if(exists($ptask{'mailtype'})){ delete($ptask{'mailtype'}) };
		if(exists($ptask{'dependency'})){ delete($ptask{'dependency'}) };
		#Registro de PET a T1w
		$ptask{'command'} = $ENV{'PIPEDIR'}."/bin/tau_reg.sh ".$study." ".$subject." ".$w_dir." ".$spet{'tau'};
		$ptask{'filename'} = $outdir.'/'.$subject.'_tau_reg.sh';
		$ptask{'output'} = $outdir.'/tau_reg_'.$subject;
		my $job_id = send2slurm(\%ptask);
		push @r_jobs, $job_id;
		my $mask_chain = "";
		my $reg_img = $w_dir.'/'.$subject.'_tau.nii.gz';
		#Hacer mascara para cada ROI
		$ptask{'job_name'} = 'tau_rois_'.$subject.'_'.$study;
		$ptask{'dependency'} = 'afterok:'.$job_id;
		foreach my $roi (@rois){
			$ptask{'output'} = $outdir.'/tau_roi_'.$roi.'_'.$subject;
			$ptask{'filename'} = $outdir.'/'.$subject.'_roi_'.$roi.'.sh';	
			$ptask{'command'} = $ENV{'PIPEDIR'}.'/bin/get_troi.sh '.$study.'_'.$subject.' '.$w_dir.'/.tmp_'.$subject.' '.$roi;
			$mask_chain.= $w_dir.'/.tmp_'.$subject.'/rois/'.$roi.'.nii.gz ';
			send2slurm(\%ptask);
		}
		#Hacer mascara de Eroded WM
#	        $ptask{'output'} = $outdir.'/tau_ewm_'.$subject;
#	        $ptask{'filename'} = $outdir.'/'.$subject.'_ewm.sh';
#	        $ptask{'command'} = $ENV{'PIPEDIR'}.'/bin/get_tref_ewm.sh '.$study.'_'.$subject.' '.$w_dir.'/.tmp_'.$subject;
#	        $mask_chain.= $w_dir.'/.tmp_'.$subject.'/rois/ewm.nii.gz ';
#	        send2slurm(\%ptask);
		#Hacer mascara de cerebelo
	        $ptask{'output'} = $outdir.'/tau_cgm_'.$subject;
	        $ptask{'filename'} = $outdir.'/'.$subject.'_cgm.sh';
	        $ptask{'command'} = $ENV{'PIPEDIR'}.'/bin/get_tref_cgm.sh '.$study.'_'.$subject.' '.$w_dir.'/.tmp_'.$subject;
	        $mask_chain.= $w_dir.'/.tmp_'.$subject.'/rois/icgm.nii.gz';
		send2slurm(\%ptask);
		#Juntar todas las mascaras en un 4D
	        $ptask{'output'} = $outdir.'/tau_merge_'.$subject;
	        $ptask{'filename'} = $outdir.'/'.$subject.'_merge.sh';
	        $ptask{'command'} = $ENV{'FSLDIR'}.'/bin/fslmerge -t '.$w_dir.'/'.$subject.'_masks '.$mask_chain;
	        #$ptask{'mailtype'} = 'FAIL,END';
	        $ptask{'dependency'} = 'singleton';
		my $mjob_id = send2slurm(\%ptask);
		#Calculo SUVR
		$ptask{'output'} = $outdir.'/tau_suvr_'.$subject;
		$ptask{'filename'} = $outdir.'/'.$subject.'_suvr.sh';
		$ptask{'command'} = $ENV{'PIPEDIR'}.'/bin/petunc.pl -i '.$w_dir.'/'.$subject.'_tau.nii.gz -m '.$w_dir.'/'.$subject.'_masks.nii.gz -o '.$w_dir.'/'.$subject.'_unc.csv';
		$ptask{'dependency'} = 'afterok:'.$mjob_id;
		my $sjob_id = send2slurm(\%ptask);
		#PVC 
		$ptask{'output'} = $outdir.'/tau_pvc_'.$subject;
		$ptask{'filename'} = $outdir.'/'.$subject.'_pvc.sh';
		$ptask{'command'} = $ENV{'PIPEDIR'}.'/bin/pvc.sh '.$subject.' '.$w_dir;
		$ptask{'dependency'} = 'afterok:'.$sjob_id;
		my $pjob_id = send2slurm(\%ptask);
		push @p_jobs, $pjob_id;	
		#PVC MTC
		$ptask{'output'} = $outdir.'/tau_mtc_'.$subject;
		$ptask{'filename'} = $outdir.'/'.$subject.'_mtc.sh';
		$ptask{'command'} = $ENV{'PIPEDIR'}.'/bin/petmtc.pl -i '.$w_dir.'/'.$subject.'_tau.nii.gz -m '.$w_dir.'/'.$subject.'_masks.nii.gz -o '.$w_dir.'/'.$subject.'_mtc.csv';
		$ptask{'dependency'} = 'afterok:'.$sjob_id;
		$pjob_id = send2slurm(\%ptask);
		push @p_jobs, $pjob_id;
	}
}
# Generating report
my %warn;
$warn{'command'} = $ENV{'PIPEDIR'}."/bin/make_tau_report.pl ".$study;
$warn{'filename'} = $outdir.'/tau_report.sh';
$warn{'job_name'} = 'tau_reg_'.$study;
$warn{'time'} = '2:0:0'; #si no ha terminado en X horas matalo
#$warn{'mailtype'} = 'FAIL,END'; #email cuando termine o falle
$warn{'output'} = $outdir.'/tau_report';
$warn{'dependency'} = 'afterok:'.join(',',@r_jobs);
send2slurm(\%warn);
# Calculating Metrics
$warn{'command'} = $ENV{'PIPEDIR'}."/bin/tau_metrics.pl -tracer ".$tracer." ".($style?" -r $style ":"").$study;
$warn{'filename'} = $outdir.'/tau_metrics.sh';
$warn{'job_name'} = 'tau_metrics_'.$study;
$warn{'time'} = '2:0:0'; #si no ha terminado en X horas matalo
$warn{'mailtype'} = 'FAIL,END'; #email cuando termine o falle
$warn{'output'} = $outdir.'/tau_metrics';
$warn{'dependency'} = 'afterok:'.join(',',@p_jobs);
send2slurm(\%warn);
