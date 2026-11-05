#!/usr/bin/perl

# Copyright 2026 O. Sotolongo <asqwerty@gmail.com>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# Main idea here is to get WMH stored values as XNAT resources
#
use strict; use warnings;
use NEURO4 qw(load_project trim);
use XNATACE qw(xget_session xget_mri xget_subjects xget_res_file xget_sbj_data xget_exp_data);
use Data::Dump qw(dump);
use File::Temp qw(:mktemp tempdir);
use Cwd qw(cwd);
my $prj;
my $xprj;
my $ofile;
my $ifile;
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
        $_ = shift;
        last if /^--$/;
	if (/^-i/) {$ifile = shift; chomp($ifile);}
        if (/^-o/) { $ofile = shift; chomp($ofile);}
        if (/^-x/) { $xprj = shift; chomp($xprj);} #nombre del proyecto en XNAT
        if (/^-p/) { $prj = shift; chomp($prj);} #nombre local del proyecto
	if (/^-h/) { 
		print "Download HIPS-THOMAS values to a table\n";
		print "usage: $0 [-o <output file>] -p <local project> [-x <xnat project>]\n";
		print "you could use local or xnat project names\n";
	}
}

# Mira, hay que meter el proyecto de XNAT con alguno de los dos switch
if ($prj and not $xprj) {
        my %pdata = load_project($prj);
        $xprj = $pdata{'XNAME'};
}
# O te vas a tomar por culo
die "Should supply XNAT project name or define it at local project config!\n" unless $xprj;
# tambien el input file porque si no no hago nada
my $tmp_dir = cwd();
my $tmpdir = tempdir(TEMPLATE => $tmp_dir.'/hipsThomas.XXXXX', CLEANUP => 1);
mkdir $tmpdir unless -d $tmpdir;
#my %xconf = xget_session();
my %data;
my @cuts;
if ($ifile){
	open IDF, "<$ifile" or die "No such input file!\n";
	@cuts = <IDF>;
	chomp @cuts;
	close IDF;
}
my %subjects = xget_subjects($xprj);
my @hemis = ('left','right');
my @ROIs=('THALAMUS' ,'AV' ,'VA' ,'VLa' ,'VLP' ,'VPL' ,'Pul' ,'LGN' ,'MGN' ,'CM' ,'MD-Pf' ,'Hb' ,'MTT' ,'Acc' ,'Cau' ,'Cla' ,'GPe' ,'GPi' ,'Put' ,'RN' ,'GP' ,'Amy');
open STDOUT, ">$ofile" unless not $ofile;
my $line = "Subject_ID,Date";
foreach my $hemi (@hemis){
	foreach my $roi (@ROIs){
		$line .= ','.$hemi.'_'.$roi;
	}
}

print STDOUT "$line\n";
foreach my $sbj (sort keys %subjects){
	my $go = 0;
	if ($ifile){
		if (grep {/$subjects{$sbj}{label}/} @cuts) {$go = 1;}
	}else{
		$go = 1;
	}
	if ($go){
		my @experiments = xget_mri($xprj, $sbj);
		#my $label = xget_sbj_data($sbj, 'label');
		foreach my $experiment (@experiments){
			my $tt = $tmpdir.'/'.$experiment;
			mkdir $tt;
			foreach my $hemi (@hemis){
			my $stat_file = $tt.'/'.$hemi.'_nucleiVols.txt';
			xget_res_file($experiment, 'HIPS', $hemi.'_nucleiVols.txt', $stat_file);
			if( -f $stat_file){
				open DFI, "$stat_file";
				while (<DFI>){
						tr/\r\n//d;
						my ($struct, $vol) = /-(.*)\s(.*)$/;
						$data{$experiment}{$hemi.'_'.$struct} = $vol;
					}
				}
				close DFI;
			}
		}
	}
}
foreach my $pollo (keys %subjects){
	my $go = 0;
	if ($ifile){
		if (grep {/$subjects{$pollo}{label}/} @cuts) {$go = 1;}
	}else{
		$go = 1;
	}
	if ($go){
		my @experiments = xget_mri($xprj, $pollo);
		my $label = xget_sbj_data($pollo, 'label');
		foreach my $experiment (@experiments){
			my $date = xget_exp_data($experiment, 'date');
			print STDOUT "$label,$date";
			foreach my $hemi (@hemis) {
				foreach my $roi (@ROIs){
					print STDOUT ",$data{$experiment}{$hemi.'_'.$roi}";
				}
			}
			print "\n";
		}
	}
}

close STDOUT;
#dump %data;
