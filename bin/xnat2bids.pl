#!/usr/bin/perl
# Copyright 2022 O. Sotolongo <asqwerty@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
use strict;
use warnings;
use NEURO4 qw(load_project);
use SLURMACE qw(send2slurm);
use XNATACE qw(xget_session xget_dicom xget_subjects xget_mri xget_exp_data);
use JSON;
use Data::Dump qw(dump);
my $prj;
my $ifile;
my $jfile;
my $mode = 'MRI'; # default mode, por ahora solo este
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-p/) { $prj = shift; chomp $prj;}
	if (/^-i/) { $ifile = shift; chomp($ifile);}
	if (/^-m/) { $mode = shift; chomp $mode;}
	if (/^-j/) { $jfile = shift; chomp $jfile;}
}
die "Should supply project name" unless $prj;
my %prj_data = load_project($prj);
$jfile = $prj_data{'BIDS'}.'/conversion.json';

#Aqui voy a leer los sujetos que voy a procesar
#en caso de que haya una lista de input
#en otro caso voy a bajar todo el proyecto
my @cuts;
if ($ifile){
	open IDF, "<$ifile" or die "No such input file!\n";
	@cuts = <IDF>;
	chomp @cuts;
	close IDF;
}
my $ord = "cat $jfile | jq '.descriptions[].criteria.SeriesDescription' | sed 's/\"//g'";
my @tags = qx/$ord/;
chomp @tags;
my $tlist = join ',', @tags;
#print "$tlist\n";

#my %xconf = xget_session();
my %subjects = xget_subjects($prj_data{'XNAME'});

foreach my $sbj (sort keys %subjects){
	if ($ifile) {
		if (grep {/$subjects{$sbj}{'label'}/} @cuts){
			$subjects{$sbj}{'download'} = 1;
		}else{
			$subjects{$sbj}{'download'} = 0;
			next;
		}
	}else{
		$subjects{$sbj}{'download'} = 1;
	}
	$subjects{$sbj}{'experiment'} = [ xget_mri($prj_data{'XNAME'}, $sbj) ];
}
my $count_id = 0;
foreach my $sbj (sort keys %subjects){
	if(exists($subjects{$sbj}{'experiment'}) and $subjects{$sbj}{'experiment'} and $subjects{$sbj}{'download'}){
		my $exp_idx = 0;
		foreach my $experiment (sort @{$subjects{$sbj}{'experiment'}}){
			my $src_dir = $prj_data{'SRC'}.'/'.$subjects{$sbj}{'label'}.($exp_idx?'_'.$exp_idx:'');
			mkdir $src_dir;
			xget_dicom($experiment, $src_dir, $tlist);
			$count_id++;
			$subjects{$sbj}{$experiment}{'strID'} = sprintf '%04d', $count_id;
			$exp_idx++;
		}
	}
}
$mode = lc $mode;
my %ptask;
$ptask{'cpus'} = 8;
$ptask{'job_name'} = 'dcm2bids_'.$prj;
$ptask{'time'} = '3:0:0';
$ptask{'mem_per_cpu'} = '4G';
my $outdir = "$prj_data{'DATA'}/slurm";
mkdir $outdir unless -d $outdir;
my $ofile = $prj_data{'DATA'}.'/'.$prj.'_'.$mode.'.csv';
my $tfile = $prj_data{'BIDS'}.'/participants.tsv';
open ODF, ">$ofile";
open TDF, ">$tfile";
my %participants;
foreach my $sbj (sort keys %subjects){
	if ($subjects{$sbj}{'download'}) {
		my $exp_idx = 0;
		foreach my $experiment (sort @{$subjects{$sbj}{'experiment'}}){
			my $exp_date =  xget_exp_data($xconf{'HOST'}, $xconf{'JSESSION'}, $experiment, 'date');
			$participants{$subjects{$sbj}{$experiment}{'strID'}}{'Date'} = $exp_date;
			$participants{$subjects{$sbj}{$experiment}{'strID'}}{'XNAT_ID'} = $sbj;
			$participants{$subjects{$sbj}{$experiment}{'strID'}}{'XNAT_'.$mode.'_ID'} = $experiment;
			$participants{$subjects{$sbj}{$experiment}{'strID'}}{'XNAT_label'} = $subjects{$sbj}{'label'};
			print ODF "$subjects{$sbj}{$experiment}{'strID'};$subjects{$sbj}{'label'}".($exp_idx?'_'.$exp_idx:'').";$exp_date\n";
			print TDF "$subjects{$sbj}{$experiment}{'strID'}\t$subjects{$sbj}{'label'}".($exp_idx?'_'.$exp_idx:'')."\t$exp_date\n";
			$ptask{'command'} = "mkdir -p $prj_data{'BIDS'}/tmp_dcm2bids/sub-$subjects{$sbj}{$experiment}{'strID'}; dcm2niix -i y -d 9 -b y -ba y -z y -f '%3s_%f_%p_%t' -o $prj_data{'BIDS'}/tmp_dcm2bids/sub-$subjects{$sbj}{$experiment}{'strID'} $prj_data{'SRC'}/$subjects{$sbj}{'label'}".($exp_idx?'_'.$exp_idx:'')."/; dcm2bids -d $prj_data{'SRC'}/$subjects{$sbj}{'label'}".($exp_idx?'_'.$exp_idx:'')."/ -p $subjects{$sbj}{$experiment}{'strID'} -c $jfile -o $prj_data{'BIDS'}/";
			$ptask{'filename'} = $outdir.'/'.$subjects{$sbj}{'label'}.($exp_idx?'_'.$exp_idx:'').'_dcm2bids.sh';
			$ptask{'output'} = $outdir.'/dcm2bids_'.$subjects{$sbj}{'label'}.($exp_idx?'_'.$exp_idx:'');
			send2slurm(\%ptask);
			$exp_idx++;
		}
	}
}
close ODF;
close TDF;
my %warn;
$warn{'filename'} = $outdir.'/dcm2bids_end.sh';
$warn{'job_name'} = 'dcm2bids_'.$prj;
$warn{'mailtype'} = 'END'; #email cuando termine
$warn{'output'} = $outdir.'/dmc2bids_end';
$warn{'dependency'} = 'singleton';
send2slurm(\%warn);
my $jdata = to_json \%participants;
my $jpfile = $prj_data{'BIDS'}.'/participants.json';
open JPF, ">$jpfile";
print JPF $jdata;
close JPF;
