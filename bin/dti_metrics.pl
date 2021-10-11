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

use File::Find::Rule;
use NEURO4 qw(get_subjects print_help get_pair get_list load_project shit_done cut_shit);
use Data::Dump qw(dump);
use File::Basename qw(basename);

my $with_sd = 0;
my $atlas = 2;
my $cfile ="";
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-a1/) { $atlas = 1;}
    if (/^-a2/) { $atlas = 2;}
    if (/^-cut/) { $cfile = shift; chomp($cfile);} 
    if (/^-sd/) { $with_sd = 1;}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/dti_metrics.hlp'; exit;}
}

my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/dti_metrics.hlp'; exit;}
my %std = load_project($study);

my $w_dir=$std{'WORKING'};
my $data_dir=$std{'DATA'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $roi_list;
my $roi_group;
my $corr = 0;
if($atlas==1){
	$roi_list = $ENV{'PIPEDIR'}.'/lib/jhu.labels.list';
	$roi_group = "labels";
}elsif($atlas==2){
	$roi_list = $ENV{'PIPEDIR'}.'/lib/jhu.tracts.list';
	$roi_group = "tracts";
	$corr = 1;
}
my $roi_dir = $ENV{'PIPEDIR'}.'/lib/jhu/';
my $jhu = "JHU_".$roi_group;
my %masks = get_pair $roi_list;
print "Collecting needed files\n";

my @dtis = cut_shit($db, $data_dir."/".$cfile);
my %csv;
my $ofile = $data_dir."/".$study."_dti_".$roi_group.".csv";
open OF, ">$ofile";

print OF "Subject";
foreach my $rmask (sort keys %masks){
	if($with_sd){
		print OF ";$masks{$rmask}","_FA_Mean;","$masks{$rmask}","_FA_STD",";$masks{$rmask}","_MD_Mean;","$masks{$rmask}","_MD_STD";
	}else{
		print OF ";$masks{$rmask}","_FA",";$masks{$rmask}","_MD";
	}
}
print OF "\n";
foreach my $subject (@dtis){
        my $dti_fa = $w_dir.'/'.$subject.'_dti_FA.nii.gz';
        my $dti_md = $w_dir.'/'.$subject.'_dti_MD.nii.gz';	
	if($subject && -e $dti_fa){
		foreach my $rmask (sort keys %masks){
			my ($m_index) = $rmask =~ /.*_(\d+)$/;
			$m_index+=$corr;
			if($m_index){
				my $order = "fslmaths ".$w_dir."/".$subject."_".$jhu." -uthr ".$m_index." -thr ".$m_index." -div ".$m_index." ".$w_dir."/.tmp_".$subject."/JHU_".$rmask."_tmp";
				print "$order\n";
				system($order);
			} else {
				my $order = "fslmaths ".$w_dir."/".$subject."_".$jhu." -uthr ".$m_index." -thr ".$m_index." ".$w_dir."/.tmp_".$subject."/JHU_".$rmask."_tmp";               
                        	print "$order\n";
                        	system($order);
			}
		}
		print OF "$subject";
		foreach my $rmask (sort keys %masks){
			my $order = "fslstats ".$dti_fa." -k ".$w_dir."/.tmp_".$subject."/JHU_".$rmask."_tmp -M -S";
			print "$order\n";
			(my $mean, my $std) = map{/(\d+\.\d*)\s*(\d+\.\d*)/} qx/$order/;
			if($with_sd){
				print OF ";$mean",";$std";
			}else{
				print OF ";$mean";
			}
                        $order = "fslstats ".$dti_md." -k ".$w_dir."/.tmp_".$subject."/JHU_".$rmask."_tmp -M -S";
                        print "$order\n";
                        ($mean, $std) = map{/(\d+\.\d*)\s*(\d+\.\d*)/} qx/$order/;
                        if($with_sd){
                                print OF ";$mean",";$std";
                        }else{
                                print OF ";$mean";
                        }                        
		}
		print OF "\n";
	}
}

close OF;
my $zfile=$std{DATA}."/".$study."_dti_".$roi_group."_results.tgz";
system("tar czf $zfile $ofile");
shit_done basename($ENV{_}), $study, $zfile;
