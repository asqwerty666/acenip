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

use NEURO4 qw(check_subj load_project print_help cut_shit check_or_make);

my $study;
my $cfile="";

@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/dti_ica_one.hlp'; exit;}
}
$study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/rs_ica_one.hlp'; exit;}
my %std = load_project($study);

my $subj_dir = $ENV{'SUBJECTS_DIR'};
my $pipe_dir = $ENV{'PIPEDIR'};
my $fsl = $ENV{'FSLDIR'};

my $w_dir=$std{'WORKING'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $data_dir=$std{'DATA'};
my $template_file = $pipe_dir.'/lib/fsf/lone_ica_template.fsf';
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);
print "Collecting needed files\n";
my @fmris = cut_shit($db, $data_dir.'/'.$cfile);
my @feats = ("feat1", "feat2", "feat4");
check_or_make($w_dir.'/.files');
system("cp $fsl'/doc/fsl.css' $w_dir'/.files'");
system("cp -r $fsl'/doc/images' $w_dir'/.files/images'");
chdir($w_dir);
foreach my $subject (sort @fmris){
	my %nifti = check_subj($std{'DATA'},$subject);
	if($nifti{'func'}){
		my $output_dir = $w_dir.'/'.$subject.'_rsout';
		check_or_make($output_dir);
		my $data = $w_dir.'/'.$subject.'_rs';
		system("$fsl'/bin/imcp' $nifti{'func'} $data");		 
		my $test_order = $fsl.'/bin/fslinfo '.$data;
		open(my $test_info, '-|', $test_order ) or die $!;
		my %test_data;
		while (<$test_info>){
		        if (/^dim1\s*(\d{1,3}).*/) {$test_data{'dim1'}=$1;}
		        if (/^dim2\s*(\d{1,3}).*/) {$test_data{'dim2'}=$1;}
		        if (/^dim3\s*(\d{1,3}).*/) {$test_data{'dim3'}=$1;}
		        if (/^dim4\s*(\d{1,3}).*/) {$test_data{'dim4'}=$1;}
		        if (/^pixdim4\s*(\d{1,2}\.\d{1,6})/) {$test_data{'tr'}=$1;}
		}		
		my $data_size = $test_data{'dim1'}*$test_data{'dim2'}*$test_data{'dim3'}*$test_data{'dim4'};
		my $data_dir = $data.'.ica';
		my $logs_dir = $data_dir.'/logs';
		my $scripts_dir = $data_dir.'/scripts';
		check_or_make($data_dir);
		check_or_make($logs_dir);
		check_or_make($scripts_dir);
		my $dsg_file = $w_dir.'/'.$subject.'_design.fsf';
		open TPF,"<$template_file";
		open DSG,">$dsg_file";
		while(<TPF>){
			s/<study>/$study/;
			s/<output_dir>/\"$output_dir\"/;
			s/<data_input>/\"$data\"/;
			s/<TR>/$test_data{'tr'}/;
			s/<number_of_slices>/$test_data{'dim4'}/;
			s/<size_of_image>/$data_size/;	
			print DSG;
		}
		close DSG;
		close TPF;
		my $jobid;
		foreach my $feat (sort @feats){
			my $template = $pipe_dir.'/lib/script_templates/'.$feat.'.template';
			my $script = $scripts_dir.'/'.$feat.'.sh';
			open TPF, "<$template";
			open SF, ">$script";
			my $name = $subject;
			while(<TPF>){
				s/<study>/$study/;
				s/<subject>/$name/;
				s/<mailto>/$ENV{'USER'}/;
				s/<out_dir>/$output_dir/;
				s/<design_file>/$dsg_file/;
				s/<data_dir>/$data_dir/g;
				s/<number>/1/;
				s/<TR>/$test_data{'tr'}/;
				print SF;
			}
			close SF;
			close TPF;
			unless($jobid){
				my $order = 'sbatch '.$script;
				print "$order\n";
				$jobid = `$order`;
				$jobid = ( split ' ', $jobid )[ -1 ];
			}else{
				my $order = 'sbatch --depend=afterok:'.$jobid.' '.$script;
				print "$order\n";
				$jobid = `$order`;
				$jobid = ( split ' ', $jobid )[ -1 ];
			}
		}
		$jobid="";
	}
}
my $orderfile = $outdir.'/feat_end.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J feat-'.$study."\n";
print ORD '#SBATCH --mail-type=END'."\n"; #email cuando termine
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -o '.$outdir.'/feat_end-%j'."\n";
print ORD ":\n";
close ORD;
my $order = 'sbatch --dependency=singleton '.$orderfile;
exec($order);
