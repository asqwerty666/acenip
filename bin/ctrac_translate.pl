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
#
use strict; use warnings;

use File::Find::Rule;
use NEURO4 qw(get_subjects print_help get_pair get_list load_project shit_done cut_shit);
use Data::Dump qw(dump);
use File::Basename qw(basename);
use File::Temp qw( :mktemp tempdir);
use Text::CSV qw( csv );

my $ifile = "";
my $ofile = "";
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-i/) { $ifile = shift; chomp($ifile);} 
    if (/^-o/) { $ofile = shift; chomp($ofile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_trasnlate.hlp'; exit;}
}

my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_translate.hlp'; exit;}
my %std = load_project($study);

my $w_dir=$std{'WORKING'};
my $data_dir=$std{'DATA'};
my $subjsdir = $ENV{'SUBJECTS_DIR'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $tmp_dir = $ENV{'TMPDIR'};

my $roi_defs = $ENV{'PIPEDIR'}.'/lib/tracula.composition.list';
my %tdata;
my %rois;

open DIRF, "<$roi_defs" or die "Can not find ROI definitions\n";
while (<DIRF>) {
	my ($roi, $def) = /(.*):(.*)/;
	$rois{$roi} = $def;
}
close DIRF;
$ifile = $data_dir."/".$study."_dti_tracula.csv" unless $ifile;
$ofile = $data_dir."/".$study."_dti_tracula_composed.csv" unless $ofile;

open IDF, "<$ifile" or die "No tracula results found\n";
my $line = 0;
my @names;
while (<IDF>) {
	chomp;
	unless ($line) {
		@names = split ';', $_;
		$line = 1;
	}else{
		my @vals = split ';', $_; 
		for my $i (1 .. $#names) {
			$tdata{$vals[0]}{$names[$i]} = $vals[$i];
		}
	}
}
close IDF;
my %sdata;
foreach my $subject (sort keys %tdata){
	foreach my $roi (sort keys %rois){
		my @chunks = split /,/,$rois{$roi};
		my $fasum = 0;
		my $mdsum = 0;
		my $vsum = 0;
		foreach my $chunk (@chunks){
			my $fan = $chunk.'_FA';
			my $mdn = $chunk.'_MD';
			my $vn = $chunk.'_Volume';
			#print "$subject -> $fan -> $tdata{$subject}{$fan}\n";
			unless ($tdata{$subject}{$fan} eq 'NA' and $tdata{$subject}{$mdn} eq 'NA' and $tdata{$subject}{$vn} eq 'NA') {
				$fasum += $tdata{$subject}{$fan}*$tdata{$subject}{$vn};
				$mdsum += $tdata{$subject}{$mdn}*$tdata{$subject}{$vn};
		       		$vsum += $tdata{$subject}{$vn};
			}
		}
		if($vsum){
			$sdata{$subject}{$roi.'_FA'} = $fasum/$vsum;
			$sdata{$subject}{$roi.'_MD'} = $mdsum/$vsum;
		}else{
			$sdata{$subject}{$roi.'_FA'} = 'NA';
			$sdata{$subject}{$roi.'_MD'} = 'NA';

		}
	}
}
open ODF, ">$ofile" or die "Could not create output file\n";
print ODF "Subject";
foreach my $roi (sort keys %rois){
	print ODF ",".$roi."_FA,".$roi."_MD";
}
print ODF "\n";
foreach my $subject (sort keys %tdata){
	print ODF "$subject";
	foreach my $roi (sort keys %rois){
		print ODF ",$sdata{$subject}{$roi.'_FA'},$sdata{$subject}{$roi.'_MD'}";
	}
	print ODF "\n";
}
		
close ODF;
#dump %sdata; exit;
#open OF, "<$ofile";

#print OF "Subject";
#foreach my $track (sort keys %trdirs){
#	print OF ";$track","_FA",";$track","_MD",";$track","_Volume";
#}
#print OF "\n";

#my %results;

#foreach my $subject (@dtis){
#	if($subject){
#		print OF "$subject";
#		my $fa; my $md; my $vol;
#		my $spath = $subjsdir.'/'.$study.'_'.$subject.'/dpath/';
#		foreach my $track (sort keys %trdirs){
#			my $ifile = $spath.$trdirs{$track}.'/'.$pathr_file;
#			if ( -e $ifile ){
#				open IRF, "<$ifile";
#				while (<IRF>) {
#					if(/^FA_Avg\s/) {($fa) = /^FA_Avg (0\.\d+)$/;}
#					if(/^MD_Avg\s/) {($md) = /^MD_Avg (0\.\d+)$/;}
#					if(/^Volume\s/) {($vol) = /^Volume (\d+)$/;}
#				}
#				close IRF;
#			}else{
#				$fa = 'NA';
#				$md = 'NA';
#				$vol = 'NA';
#			}
#			if($fa && $md){
#				print OF ";$fa;$md;$vol";
#			}else{
#				print OF ";NA;NA;NA";
#			}
#		}
#		print OF "\n";
#	}
#}

#close OF;
#my $zfile=$std{DATA}."/".$study."_dti_tracula_results.tgz";
#system("tar czf $zfile $ofile");
#shit_done basename($ENV{_}), $study, $zfile;
