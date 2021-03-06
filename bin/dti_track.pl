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
#
use strict; use warnings;
use File::Slurp qw(read_file);
use File::Find::Rule;
use File::Basename qw(basename);
use Data::Dump qw(dump);
use File::Copy::Recursive qw(dirmove);
use NEURO4 qw(load_project print_help cut_shit check_or_make);

my $study;
my $cfile;
my $debug=1;
my $atlas=0; 
my $network;
my $t1=0;
my $time = '8:0:0';
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-t1/) {$t1 = 1;}
    if (/^-time/) {$time = shift; chomp($time)}
    if (/^-uofm/) {$atlas="uofm"; $network = shift; chomp($network); $network =~ s/\_/\//g;}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/dti_track.hlp'; exit;}
}
$study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/dti_track.hlp'; exit;}

my %std = load_project($study);
my $subj_dir = $ENV{'SUBJECTS_DIR'};
my $pipe_dir = $ENV{'PIPEDIR'};
# Redirect ouput to logfile (do it only when everything is fine)
my $logfile = "$std{'DATA'}/.debug_dti_tracks.log";
open STDOUT, ">$logfile" or die "Can't redirect stdout";
open STDERR, ">&STDOUT" or die "Can't dup stdout";
$debug ? open DBG, ">$logfile" :0;

my $w_dir=$std{'WORKING'};
my $data_dir=$std{'DATA'};
my $db = $data_dir.'/'.$study.'_mri.csv';
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);
#my $jobname = "track_$study";

my @dtis = cut_shit($db, $data_dir.'/'.$cfile);
my %ptask = ('job_name' => 'dti_track_'.$study,
	'time' => $time,
	'mailtype' => 'FAIL,TIME_LIMIT,STAGE_OUT',
	'gres' => 'gpu:1',
	'partition' => 'cuda',
);
foreach my $subject (@dtis){
	#Compulsory: el DTI debe haber pasado el preproc
	my $dti_fa = $w_dir.'/'.$subject.'_dti_FA.nii.gz';
	#Compulsory: Necesito tambien la segmentacion de freesurfer de este pollo
	my $aseg = $subj_dir.'/'.$study.'_'.$subject.'/mri/aseg.mgz';
	if((-e $dti_fa) && (-e $aseg)){
		my $order;
		unless($atlas){
			if($t1){
				$order = $pipe_dir."/bin/dti_bedtrack_cuda_t1.sh ".$study." ".$subject." ".$w_dir;
			}else{
				$order = $pipe_dir."/bin/dti_bedtrack_cuda.sh ".$study." ".$subject." ".$w_dir;
			}
		}else{
			if($t1){
				$order = $pipe_dir."/bin/dti_bedtrack_nodes_t1.sh ".$study." ".$subject." ".$w_dir." ".$pipe_dir."/lib/".$atlas."/Nodes/".$network;
			}else{
				$order = $pipe_dir."/bin/dti_bedtrack_nodes.sh ".$study." ".$subject." ".$w_dir." ".$pipe_dir."/lib/".$atlas."/Nodes/".$network;
			}
		}
		#$count++;
		#print CNF "$order\n";
		$ptask{'filename'} = $outdir.'/'.$subject.'dti_orders.sh';
		$ptask{'output'} = $outdir.'/dti_track-'.$subject.'-'.$study;
		$ptask{'command'} = $order;
		send2slurm(\%ptask);
		$debug ? print DBG "$order\n" :0;
	}
}
my %final = ('filename' => $outdir.'/dti_track_end.sh',
	'job_name' => 'dti_track_'.$study,
	'mailtype' => 'END',
	'output' => $outdir.'/dti_track_end',
	'dependency' => 'singleton',
);
send2slurm(\%final);

