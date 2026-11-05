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
		print "Download LST-AI values to a table\n";
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
my $tmpdir = tempdir(TEMPLATE => $tmp_dir.'/lstAI.XXXXX', CLEANUP => 1);
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
my @ROIs=('Periventricular','Juxtacortical','Subcortical','Infratentorial');
open STDOUT, ">$ofile" unless not $ofile;
my $line = "Subject_ID,Date,Num_Lesions,Num_Vox,Lesion_Volume,";
foreach my $roi (@ROIs){
	$line .= $roi.'_Num_Lesions,'.$roi.'_Num_Vox,'.$roi.'_Lesion_Volume,';
}
$line = substr($line, 0, -1);
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
			my $stat_file = $tt.'/lesion_stats.csv';
			xget_res_file($experiment, 'LSTAI', 'lesion_stats.csv', $stat_file);
			if( -f $stat_file){
				my $sdata = `grep -v Num_Lesions $stat_file`;
				$sdata =~ tr/\r\n//d;
				my @strdata = split ',', $sdata;
				$data{$experiment}{Num_Lesions} = $strdata[0];
				$data{$experiment}{Num_Vox} = $strdata[1];
				$data{$experiment}{Lesion_Volume} = $strdata[2];
			}
			$stat_file = $tt.'/annotated_lesion_stats.csv';
			my $dbg = xget_res_file($experiment, 'LSTAI', 'annotated_lesion_stats.csv', $stat_file);
			if( -f $stat_file){
				open DFI, "$stat_file";
				while (<DFI>){
					unless (/.*Num_Lesions.*/){
						tr/\r\n//d;
						my @strdata = split ',', $_;
						my $name = $strdata[0];
						$data{$experiment}{$name.'_Num_Lesions'} = $strdata[1];
						$data{$experiment}{$name.'_Num_Vox'} = $strdata[2];
						$data{$experiment}{$name.'_Lesion_Volume'} = $strdata[3];
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
			if (exists($data{$experiment}{Num_Lesions}) and $data{$experiment}{Num_Lesions}){
				print STDOUT "$label,$date,$data{$experiment}{Num_Lesions},$data{$experiment}{Num_Vox},$data{$experiment}{Lesion_Volume}";
				foreach my $roi (@ROIs){
					print STDOUT ",$data{$experiment}{$roi.'_Num_Lesions'},$data{$experiment}{$roi.'_Num_Vox'},$data{$experiment}{$roi.'_Lesion_Volume'}";
				}
				print "\n";
			}
		}
	}
}

close STDOUT;
#dump %data;
