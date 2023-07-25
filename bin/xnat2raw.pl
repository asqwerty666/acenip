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

use strict; use warnings;
use NEURO4 qw(load_project print_help);
use XNATACE qw(xget_session xget_subjects xget_mri xget_pet xget_dicom);
use SLURMACE qw(send2slurm);
use File::Temp qw(:mktemp tempdir);
use Data::Dump qw(dump);
my $mode = 'MRI';
my $ifile = '';
my $prj;
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-p/) { $prj = shift; chomp $prj;}
	if (/^-i/) { $ifile = shift; chomp($ifile);}
	if (/^-m/) { $mode = shift; chomp $mode;}
}
die "Should supply project name" unless $prj;
my $tmp_dir = $ENV{'TMPDIR'};
my %prj_data = load_project($prj);
my @cuts;
if ($ifile){
	open IDF, "<$ifile" or die "No such input file!\n";
	@cuts = <IDF>;
	chomp @cuts;
	close IDF;
}
my %xconf = xget_session();
my %subjects = xget_subjects($xconf{'HOST'}, $xconf{'JSESSION'}, $prj_data{'XNAME'});
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
	if ($mode eq 'MRI'){
		$subjects{$sbj}{'experiment'} = [xget_mri($xconf{'HOST'}, $xconf{'JSESSION'}, $prj_data{'XNAME'}, $sbj)];
	}elsif ($mode eq 'PET') {
		$subjects{$sbj}{'experiment'} = [xget_pet($xconf{'HOST'}, $xconf{'JSESSION'}, $prj_data{'XNAME'}, $sbj)];
	}else{
		print "Only MRI and PET type are allowed\n";
		exit;
	}
}
my $count_id = 0;
foreach my $sbj (sort keys %subjects){
	if(exists($subjects{$sbj}{'experiment'}) and $subjects{$sbj}{'experiment'} and $subjects{$sbj}{'download'}){
		my $exp_idx = 0;
		foreach my $experiment (sort @{$subjects{$sbj}{'experiment'}}){
			my $src_dir = $prj_data{'SRC'}.'/'.$subjects{$sbj}{'label'}.($exp_idx?'_'.$exp_idx:'');
			mkdir $src_dir;
			xget_dicom($xconf{'HOST'}, $xconf{'JSESSION'}, $experiment, $src_dir);
			$count_id++;
			$subjects{$sbj}{$experiment}{'strID'} = sprintf '%04d', $count_id;
			$exp_idx++;
		}
	}
}
my $ofile = $prj_data{'DATA'}.'/'.$prj.'_'.$mode.'.csv';
open ODF, ">$ofile";
foreach my $sbj (sort keys %subjects){
	if ($subjects{$sbj}{'download'}) {
		my $exp_idx = 0;
		foreach my $experiment (sort @{$subjects{$sbj}{'experiment'}}){
			print ODF "$subjects{$sbj}{$experiment}{'strID'},$subjects{$sbj}{'label'}".($exp_idx?'_'.$exp_idx:'')."\n";
			$exp_idx++;
		}
	}
}

close ODF;
