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
#my %trdirs = ( 'fmajor' => 'fmajor_PP_avg33_mni_bbr',
#	'lh.cab' => 'lh.cab_PP_avg33_mni_bbr',
#  	'lh.ilf' => 'lh.ilf_AS_avg33_mni_bbr',
#	'lh.unc' => 'lh.unc_AS_avg33_mni_bbr',
#	'rh.cab' => 'rh.cab_PP_avg33_mni_bbr',
#	'rh.ilf' => 'rh.ilf_AS_avg33_mni_bbr',
#	'rh.unc' => 'rh.unc_AS_avg33_mni_bbr',
#	'fminor' => 'fminor_PP_avg33_mni_bbr',
#	'lh.ccg' => 'lh.ccg_PP_avg33_mni_bbr',
#	'lh.slfp' => 'lh.slfp_PP_avg33_mni_bbr',
#	'rh.ccg' => 'rh.ccg_PP_avg33_mni_bbr',
#	'rh.slfp' => 'rh.slfp_PP_avg33_mni_bbr',
#	'lh.atr' => 'lh.atr_PP_avg33_mni_bbr',
#	'lh.cst' => 'lh.cst_AS_avg33_mni_bbr',
#	'lh.slft' => 'lh.slft_PP_avg33_mni_bbr',
#	'rh.atr' => 'rh.atr_PP_avg33_mni_bbr',
#	'rh.cst' => 'rh.cst_AS_avg33_mni_bbr',
#	'rh.slft' => 'rh.slft_PP_avg33_mni_bbr',
#);
my %trdirs = (
'acomm' => 'acomm_avg16_syn_bbr',
'cc.bodyc' => 'cc.bodyc_avg16_syn_bbr',
'cc.bodyp' => 'cc.bodyp_avg16_syn_bbr',
'cc.bodypf' => 'cc.bodypf_avg16_syn_bbr',
'cc.bodypm' => 'cc.bodypm_avg16_syn_bbr',
'cc.bodyt' => 'cc.bodyt_avg16_syn_bbr',
'cc.genu' => 'cc.genu_avg16_syn_bbr',
'cc.rostrum' => 'cc.rostrum_avg16_syn_bbr',
'cc.splenium' => 'cc.splenium_avg16_syn_bbr',
'lh.af' => 'lh.af_avg16_syn_bbr',
'lh.ar' => 'lh.ar_avg16_syn_bbr',
'lh.atr' => 'lh.atr_avg16_syn_bbr',
'lh.cbd' => 'lh.cbd_avg16_syn_bbr',
'lh.cbv' => 'lh.cbv_avg16_syn_bbr',
'lh.cst' => 'lh.cst_avg16_syn_bbr',
'lh.emc' => 'lh.emc_avg16_syn_bbr',
'lh.fat' => 'lh.fat_avg16_syn_bbr',
'lh.fx' => 'lh.fx_avg16_syn_bbr',
'lh.ilf' => 'lh.ilf_avg16_syn_bbr',
'lh.mlf' => 'lh.mlf_avg16_syn_bbr',
'lh.or' => 'lh.or_avg16_syn_bbr',
'lh.slf1' => 'lh.slf1_avg16_syn_bbr',
'lh.slf2' => 'lh.slf2_avg16_syn_bbr',
'lh.slf3' => 'lh.slf3_avg16_syn_bbr',
'lh.uf' => 'lh.uf_avg16_syn_bbr',
'mcp' => 'mcp_avg16_syn_bbr',
'rh.af' => 'rh.af_avg16_syn_bbr',
'rh.ar' => 'rh.ar_avg16_syn_bbr',
'rh.atr' => 'rh.atr_avg16_syn_bbr',
'rh.cbd' => 'rh.cbd_avg16_syn_bbr',
'rh.cbv' => 'rh.cbv_avg16_syn_bbr',
'rh.cst' => 'rh.cst_avg16_syn_bbr',
'rh.emc' => 'rh.emc_avg16_syn_bbr',
'rh.fat' => 'rh.fat_avg16_syn_bbr',
'rh.fx' => 'rh.fx_avg16_syn_bbr',
'rh.ilf' => 'rh.ilf_avg16_syn_bbr',
'rh.mlf' => 'rh.mlf_avg16_syn_bbr',
'rh.or' => 'rh.or_avg16_syn_bbr',
'rh.slf1' => 'rh.slf1_avg16_syn_bbr',
'rh.slf2' => 'rh.slf2_avg16_syn_bbr',
'rh.slf3' => 'rh.slf3_avg16_syn_bbr',
'rh.uf' => 'rh.uf_avg16_syn_bbr',
);
my $pathr_file = 'pathstats.overall.txt';
print "Collecting needed files\n";

my @dtis = cut_shit($db, $data_dir."/".$cfile);

my %csv;

my $ofile = $data_dir."/".$study."_dti_tracula.csv";
open OF, ">$ofile";

print OF "Subject";
foreach my $track (sort keys %trdirs){
	print OF ";$track","_FA",";$track","_MD",";$track","_Volume";
}
print OF "\n";

my %results;

foreach my $subject (@dtis){
	if($subject){
		print OF "$subject";
		my $fa; my $md; my $vol;
		my $spath = $subjsdir.'/'.$study.'_'.$subject.'/dpath/';
		foreach my $track (sort keys %trdirs){
			my $ifile = $spath.$trdirs{$track}.'/'.$pathr_file;
			if ( -e $ifile ){
				open IRF, "<$ifile";
				while (<IRF>) {
					if(/^FA_Avg\s/) {($fa) = /^FA_Avg (0\.\d+)$/;}
					if(/^MD_Avg\s/) {($md) = /^MD_Avg (0\.\d+)$/;}
					if(/^Volume\s/) {($vol) = /^Volume (\d+)$/;}
				}
				close IRF;
			}else{
				$fa = 'NA';
				$md = 'NA';
				$vol = 'NA';
			}
			if($fa && $md){
				print OF ";$fa;$md;$vol";
			}else{
				print OF ";NA;NA;NA";
			}
		}
		print OF "\n";
	}
}

close OF;
my $zfile=$std{DATA}."/".$study."_dti_tracula_results.tgz";
system("tar czf $zfile $ofile");
shit_done basename($ENV{_}), $study, $zfile;
