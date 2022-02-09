#!/usr/bin/perl

# Copyright 2018 O. Sotolongo <asqwerty@gmail.com>

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
use File::Copy qw(copy);

use NEURO4 qw(cut_shit check_subj load_project print_help check_or_make);

my $study;
my $cfile="";

@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/rs_ica_one.hlp'; exit;}
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
my $lone_template_file = $pipe_dir.'/lib/fsf/notalone_ica_template.fsf';
my %template_files = ( "begin" => $pipe_dir.'/lib/fsf/group_ica_template_p1.fsf', 
					"data" => $pipe_dir.'/lib/fsf/group_ica_template_targets.fsf', 
					"end" => $pipe_dir.'/lib/fsf/group_ica_template_p2.fsf');
my $error_data_file = $data_dir.'/fmri_image_errors.txt';

print "Collecting needed files\n";
my @fmris = cut_shit($db, $data_dir.'/'.$cfile);

my $count = 0;
my %subjects;
print "Counting available subjects\n";
foreach my $subject (sort @fmris){
	my %nifti = check_subj($std{'DATA'},$subject);
	if($nifti{'func'}){
		my $sname = $subject;
		$subjects{$sname} = $nifti{'func'}; 
		$count++;
	}
}
my $pollos = $count;
print "Getting info from images\n";
my $test_subject = ( sort keys %subjects )[0];
my $test_path = $subjects{$test_subject};
my $test_order = $fsl.'/bin/fslinfo '.$test_path;
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
print "Checking images and excluding wrong subjects\n";
open(EDF, ">$error_data_file");
foreach my $subject (sort keys %subjects){
	my $sub_path = $subjects{$subject};
	my $order = $fsl.'/bin/fslinfo '.$sub_path;
	open(my $sub_info, '-|', $order ) or die $!;
	my %sub_data;
	while (<$sub_info>){
		if (/^dim1\s*(\d{1,3}).*/) {$sub_data{'dim1'}=$1;}
		if (/^dim2\s*(\d{1,3}).*/) {$sub_data{'dim2'}=$1;}
		if (/^dim3\s*(\d{1,3}).*/) {$sub_data{'dim3'}=$1;}
		if (/^dim4\s*(\d{1,3}).*/) {$sub_data{'dim4'}=$1;}
		if (/^pixdim4\s*(\d{1,2}\.\d{1,6})/) {$sub_data{'tr'}=$1;}
	} 
	unless(($sub_data{'dim1'} == $test_data{'dim1'}) && ($sub_data{'dim2'} == $test_data{'dim2'}) && ($sub_data{'dim3'} == $test_data{'dim3'}) && ($sub_data{'dim4'} == $test_data{'dim4'}) && ($sub_data{'tr'} == $test_data{'tr'})){
		print EDF "\n$subject\ndim1: $sub_data{'dim1'}\ndim2: $sub_data{'dim2'}\ndim3: $sub_data{'dim3'}\ndim4: $sub_data{'dim4'}\ntr: $sub_data{'tr'}\n";
		delete($subjects{$subject});
		$pollos--;
	}
} 
close EDF;
my $subs_size = keys %subjects;
unless ($subs_size > 1){
	my ($bad) = %subjects; 
	print "Error: bad subject taken as reference or individual group\n";
	print "Delete subject $bad from list and try again\n";
	exit;
}
#print "Everything is fine. You pass the test\n"; dump %subjects; exit;
print "Copying FSL files and setting directories\n";
my @feats = ("feat1", "feat2");
my $gfeat = "feat4_ica";
check_or_make($w_dir.'/.files');
system("cp $fsl'/doc/fsl.css' $w_dir'/.files'");
system("cp -r $fsl'/doc/images' $w_dir'/.files/images'");
chdir($w_dir);
my @jobs_list;
my $gdata_dir = $w_dir.'/rs.gica';
my $output_dir = $w_dir.'/rsout_gica';
check_or_make($output_dir);
check_or_make($gdata_dir);
my $dsg_file = $w_dir.'/gica_design.fsf';
open DSG,">$dsg_file";
open TPF,"<$template_files{'begin'}";

print "Making global .fsf file\n";
while(<TPF>){
	s/<output_dir>/\"$output_dir\"/;
	s/<number_of_subjects>/$pollos/;
	s/<number_of_slices>/$test_data{'dim4'}/;
	s/<size_of_image>/$data_size/; 
	s/<TR>/$test_data{'tr'}/;
	print DSG;
}
close TPF;
$count = 1;
my $filtered_list = $gdata_dir.'/.filelist';
open FCK, ">$filtered_list";
foreach my $subject (sort keys %subjects){
		my $idata = $w_dir.'/'.$subject.'_rs.ica';
		my $fck_line = $idata.'/reg_standard/filtered_func_data';
		print FCK "$fck_line\n";
		open TPF,"<$template_files{'data'}";
		while(<TPF>){
			s/<data>/$idata/;
			s/<number_of_sample>/$count/;
			print DSG;
		}
		$count++;
		close TPF;
}
close FCK;
open TPF,"<$template_files{'end'}";
while(<TPF>){
	print DSG;
}
close TPF;
close DSG;

print "Making individual .fsf files and scripts\n";
my $tranca="";
$count = 1;
foreach my $subject (sort keys %subjects){
		my $idata = $w_dir.'/'.$subject.'_rs';
		open TPF,"<$template_files{'data'}";
		while(<TPF>){
			s/<data>/$idata/;
			s/<number_of_sample>/$count/;
			$tranca .= $_;
		}
		$count++;
		close TPF;
}

$count = 1;
foreach my $subject (sort keys %subjects){
		my $ioutput_dir = $w_dir.'/'.$subject.'_rsout';
		check_or_make($ioutput_dir);
		my $idata = $w_dir.'/'.$subject.'_rs';
		my $idata_dir = $idata.'.ica';
		my $ilogs_dir = $idata_dir.'/logs';
		my $iscripts_dir = $idata_dir.'/scripts';
		check_or_make($idata_dir);
		check_or_make($ilogs_dir);
		check_or_make($iscripts_dir);
		my $idsg_file = $w_dir.'/'.$subject.'_rs.ica/design.fsf';
		open TPF,"<$lone_template_file";
		open DSG,">$idsg_file";
		while(<TPF>){
			s/<output_dir>/\"$ioutput_dir\"/;
			s/<full_data>/$tranca/;
			s/<TR>/$test_data{'tr'}/;
			s/<number_of_slices>/$test_data{'dim4'}/;
			s/<size_of_image>/$data_size/;
			s/<number_of_subjects>/$pollos/;
			print DSG;
		}
		close DSG;
		close TPF;		
		system("$fsl'/bin/imcp' $subjects{$subject} $idata"); 
		
		my $jobid;
		foreach my $feat (sort @feats){
			my $template = $pipe_dir.'/lib/script_templates/'.$feat.'.template';
			my $script = $iscripts_dir.'/'.$feat.'.sh';
			open TPF, "<$template";
			open SF, ">$script";
			while(<TPF>){
				s/<study>/$study/;
				s/<subject>/$subject/;
				s/<mailto>/$ENV{'USER'}/;
				s/<out_dir>/$ioutput_dir/;
				s/<design_file>/$idsg_file/;
				s/<data_dir>/$idata_dir/g;
				s/<number>/$count/;
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
				push @jobs_list, $jobid;
			}
		}
		$jobid="";
		$count++;
}

print "Making global script\n";
my $logs_dir = $gdata_dir.'/logs';
my $scripts_dir = $gdata_dir.'/scripts';
check_or_make($logs_dir);
check_or_make($scripts_dir);

my $template = $pipe_dir.'/lib/script_templates/'.$gfeat.'.template';
my $script = $scripts_dir.'/'.$gfeat.'.sh';
open TPF, "<$template";
open SF, ">$script";
while(<TPF>){
	s/<study>/$study/;
	s/<mailto>/$ENV{'USER'}/;
	s/<out_dir>/$output_dir/;
	s/<design_file>/$dsg_file/;
	s/<output_dir>/$gdata_dir/g;
	print SF;
}
close SF;
close TPF;
my $sjobs = join(',',@jobs_list);
my $order = 'sbatch --depend=afterok:'.$sjobs.' '.$script;
print "$order\n";
exec($order);

