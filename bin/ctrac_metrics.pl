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
#
use strict; use warnings;

use File::Find::Rule;
use NEURO4 qw(get_subjects print_help get_pair get_list load_project shit_done cut_shit);
use Data::Dump qw(dump);
use File::Basename qw(basename);

my $cfile ="";
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);} 
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_metrics.hlp'; exit;}
}

my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_metrics.hlp'; exit;}
my %std = load_project($study);

my $w_dir=$std{'WORKING'};
my $data_dir=$std{'DATA'};
my $subjsdir = $ENV{'SUBJECTS_DIR'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my %trdirs = ( 'fmajor' => 'fmajor_PP_avg33_mni_bbr',
	'lh.cab' => 'lh.cab_PP_avg33_mni_bbr',
  	'lh.ilf' => 'lh.ilf_AS_avg33_mni_bbr',
	'lh.unc' => 'lh.unc_AS_avg33_mni_bbr',
	'rh.cab' => 'rh.cab_PP_avg33_mni_bbr',
	'rh.ilf' => 'rh.ilf_AS_avg33_mni_bbr',
	'rh.unc' => 'rh.unc_AS_avg33_mni_bbr',
	'fminor' => 'fminor_PP_avg33_mni_bbr',
	'lh.ccg' => 'lh.ccg_PP_avg33_mni_bbr',
	'lh.slfp' => 'lh.slfp_PP_avg33_mni_bbr',
	'rh.ccg' => 'rh.ccg_PP_avg33_mni_bbr',
	'rh.slfp' => 'rh.slfp_PP_avg33_mni_bbr',
	'lh.atr' => 'lh.atr_PP_avg33_mni_bbr',
	'lh.cst' => 'lh.cst_AS_avg33_mni_bbr',
	'lh.slft' => 'lh.slft_PP_avg33_mni_bbr',
	'rh.atr' => 'rh.atr_PP_avg33_mni_bbr',
	'rh.cst' => 'rh.cst_AS_avg33_mni_bbr',
	'rh.slft' => 'rh.slft_PP_avg33_mni_bbr',
);
my $pathr_file = 'pathstats.overall.txt';
print "Collecting needed files\n";

my @dtis = cut_shit($db, $data_dir."/".$cfile);

my %csv;

my $ofile = $data_dir."/".$study."_dti_tracula.csv";
open OF, ">$ofile";

print OF "Subject";
foreach my $track (sort keys %trdirs){
	print OF ";$track","_FA",";$track","_MD";
}
print OF "\n";

my %results;

foreach my $subject (@dtis){
	if($subject){
		print OF "$subject";
		my $fa; my $md;
		my $spath = $subjsdir.'/'.$study.'_'.$subject.'/dpath/';
		foreach my $track (sort keys %trdirs){
			my $ifile = $spath.$trdirs{$track}.'/'.$pathr_file;
			open IRF, "<$ifile";
			while (<IRF>) {
				if(/^FA_Avg\s/) {($fa) = /^FA_Avg (0\.\d+)$/;}
				if(/^MD_Avg\s/) {($md) = /^MD_Avg (0\.\d+)$/;}
			}
			close IRF;
		print OF ";$fa;$md";
		}
		print OF "\n";
	}
}

close OF;
my $zfile=$std{DATA}."/".$study."_dti_tracula_results.tgz";
system("tar czf $zfile $ofile");
shit_done basename($ENV{_}), $study, $zfile;
