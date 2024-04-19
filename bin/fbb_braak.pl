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
use JSON qw(decode_json);
use NEURO4 qw(check_pet check_subj load_project print_help check_or_make cut_shit get_pair);
use SLURMACE qw(send2slurm);
use FSMetrics qw(tau_rois);
use XNATACE qw(xget_pet xget_session xget_pet_reg); 
my $cfile="";
my $time = '2:0:0';
my $style = "";
my $xprj = "";
my $study;

@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-time/) {$time = shift; chomp($time);}
    if (/^-r/) {$style = shift; chomp($style);}
#    if (/^-tracer/) {$tracer = shift; chomp($tracer);}
    if (/^-x/) {$xprj = shift; chomp $xprj;}
    if (/^-p/) {$study = shift; chomp $study;}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/tau_reg.hlp'; exit;}
}
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/tau_reg.hlp'; exit;}
unless ($xprj) {die "Should supply XNAT project\n"; }
my %std = load_project($study);

my $subj_dir = $ENV{'SUBJECTS_DIR'};

my $w_dir=$std{'WORKING'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $data_dir=$std{'DATA'};
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

print "Collecting needed files\n";
my @pets = cut_shit($db, $data_dir.'/'.$cfile);
my %pet_data = get_pair($db);
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
#my %xconf_data = xget_session();
#my $jsession = $xconf_data{'JSESSION'};
foreach my $subject (@pets){ 
	my $psubject = $pet_data{$subject};
	my $fake_tau = $w_dir.'/'.$subject.'_tau.nii.gz';
	#print "$fake_tau\n";
	my $xrd = xget_pet($xprj, $psubject);
#	if ($xrd){
#		my $xld = 'curl -f -X GET -b "JSESSIONID='.$jsession.'" "'.$xconf_data{'HOST'}.'/data/experiments/'.$xrd.'/files?format=json" 2>/dev/null';
		#print "$xld\n";
#		my $jres = qx/$xld/;
#		my $xfres = decode_json $jres;
#		foreach my $xres (@{$xfres->{'ResultSet'}{'Result'}}){
#			if ($xres->{'file_content'} eq 'PET_reg'){
#				my $xuri = $xres->{'URI'};
#				my $grd = 'curl -f -b "JSESSIONID='.$jsession.'" -X GET "'.$xconf_data{'HOST'}.$xuri.'" -o '.$fake_tau.' 2>/dev/null';
#				system($grd);
#			}
#		}
#	}
	xget_pet_reg($xprj, $fake_tau);
	my %smri = check_subj($std{'DATA'},$subject);
	if(-e $fake_tau && $smri{'T1w'}){
		push @ok_pets, $subject;
		if(exists($ptask{'mailtype'})){ delete($ptask{'mailtype'}) };
		if(exists($ptask{'dependency'})){ delete($ptask{'dependency'}) };
		#Registro de PET a T1w
		#Ya esta hecho por XNAT
		my $mask_chain = "";
		my $reg_img = $fake_tau;
		#Hacer mascara para cada ROI
		$ptask{'job_name'} = 'tau_rois_'.$subject.'_'.$study;
		foreach my $roi (@rois){
			$ptask{'output'} = $outdir.'/tau_roi_'.$roi.'_'.$subject;
			$ptask{'filename'} = $outdir.'/'.$subject.'_roi_'.$roi.'.sh';	
			$ptask{'command'} = $ENV{'PIPEDIR'}.'/bin/get_troi.sh '.$study.'_'.$subject.' '.$w_dir.'/.tmp_'.$subject.' '.$roi;
			$mask_chain.= $w_dir.'/.tmp_'.$subject.'/rois/'.$roi.'.nii.gz ';
			send2slurm(\%ptask);
		}
		#Hacer mascara de cerebelo
	        $ptask{'output'} = $outdir.'/tau_cgm_'.$subject;
	        $ptask{'filename'} = $outdir.'/'.$subject.'_cgm.sh';
	        $ptask{'command'} = $ENV{'PIPEDIR'}.'/bin/get_fref_cgm.sh '.$study.'_'.$subject.' '.$w_dir.'/.tmp_'.$subject;
	        $mask_chain.= $w_dir.'/.tmp_'.$subject.'/rois/cerebgm.nii.gz';
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
		push @p_jobs, $sjob_id;	
	}
}
my %warn;
# Calculating Metrics
$warn{'command'} = $ENV{'PIPEDIR'}."/bin/fake_metrics.pl ".($style?" -r $style ":"").$study;
$warn{'filename'} = $outdir.'/fake_metrics.sh';
$warn{'job_name'} = 'fake_metrics_'.$study;
$warn{'time'} = '2:0:0'; #si no ha terminado en X horas matalo
$warn{'mailtype'} = 'FAIL,END'; #email cuando termine o falle
$warn{'output'} = $outdir.'/fake_metrics';
$warn{'dependency'} = 'afterok:'.join(',',@p_jobs);
send2slurm(\%warn);
