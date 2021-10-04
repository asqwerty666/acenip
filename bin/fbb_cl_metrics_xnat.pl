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

use strict; use warnings;
use Cwd qw(cwd);
use NEURO4 qw(load_project print_help populate check_or_make getLoggingTime);
use Spreadsheet::Write;
use Text::CSV qw( csv );
use Data::Dump qw(dump);
use File::Temp qw( :mktemp tempdir);
use File::Path qw(make_path);

my $internos;
my $guide;
my $ofile;
my $debug = 1;
my @qcpass = ("No Pass", "Pass");
my $info_page = $ENV{PIPEDIR}.'/lib/info_page_fbb.csv';
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-i/) { $internos = shift; chomp($internos);}
	if (/^-g/) { $guide = shift; chomp($guide);}
	if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/fbb_metrics.hlp'; exit;}
}
# Este es el proyecto en XNAT. Es obligatorio.
my $study = shift;
my $tmp_dir = $ENV{'TMPDIR'};
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/fbb_metrics.hlp'; exit;}
unless ($debug) {
	my $logfile = 'fbb_metrics_xnat.log';
	open STDOUT, ">$logfile" or die "Can't redirect stdout";
	open STDERR, ">&STDOUT" or die "Can't dup stdout";
	open DBG, ">$logfile";
}
$ofile = $study.'_fbb_cl_metrics_'.getLoggingTime().'.xls';
my %guys;
my $subjects_list = mktemp($tmp_dir.'/sbjsfileXXXXX');
# Get subject list
my $order = 'xnatapic list_subjects --project_id '.$study.' --label > '.$subjects_list;
system($order);
open SLF, "<$subjects_list";
while(<SLF>){
	my ($stag, $slab) = /(.*),(.*)/;
	chomp($slab);
	$guys{$slab}{'XNATSBJ'} = $stag;
	my $xnat_order = 'xnatapic list_experiments --project_id '.$study.' --subject_id '.$stag.' --modality PET --date';
	my $xtag = qx/$xnat_order/;
	chomp($xtag);
	if($xtag){
		my ($xnam, $xdate) = $xtag =~ /(.*),(.*)/;
		$guys{$slab}{'XNATEXP'} = $xnam;
		#$xdate =~ s/-/./g;
		$guys{$slab}{'DATE'} = $xdate;
	}
}
close SLF; 
unlink $subjects_list;
# to guide or not to guide?
unless ($guide) {
	$guide = mktemp($tmp_dir.'/guide_data.XXXXX');
	open GDF, ">$guide";
	if ($internos){
		open IIF, "<$internos";
		while (<IIF>){
			if (/.*,\d{8}$/){
				my ($sbj, $interno) = /(.*),(\d{8})$/;
				$guys{$sbj}{'INTERNO'} = $interno;
			}
		}
		close IIF;
		print GDF "Subject,Interno,Date\n";
		foreach my $plab (sort keys %guys){
			if (exists($guys{$plab}{'INTERNO'}) and exists($guys{$plab}{'DATE'})){
				print GDF "$plab,$guys{$plab}{'INTERNO'},$guys{$plab}{'DATE'}\n";
				print "$plab,$guys{$plab}{'INTERNO'},$guys{$plab}{'DATE'}\n";
			}
		}
	}else{
		print GDF "Subject,Date\n";
		foreach my $plab (sort keys %guys){
			print GDF "$plab,$guys{$plab}{'DATE'}\n";
		}
	}
	close GDF;
}
# TMP shit
my $fbbout = tempdir(TEMPLATE => $tmp_dir.'/fsout.XXXXX', CLEANUP => 1);
# Get FBB results
my $fbfile = $fbbout.'/fbbcl.csv';
$order = 'xnatapic get_fbbcl --project_id '.$study.' --output '.$fbfile;
system($order);
open CLF, "<$fbfile";
while(<CLF>){
	if(/, \d$/){
		my ($sbj, $suvr, $cl, $qc) = /(.*), (.*), (.*), (.*)$/;
		$guys{$sbj}{'SUVR'} = $suvr;
		$guys{$sbj}{'CL'} = $cl;
		$guys{$sbj}{'QC'} = $qcpass[$qc];
	}
}
close CLF;
# make xls file
# info first
my $info = csv (in => $info_page);
my $workbook = Spreadsheet::Write->new(file => $ofile, sheet => 'Info');
for my $i (0 .. $#{$info}) {
	my $row = $info->[$i];
	$workbook->addrow($row);
}
#now regroup data
$workbook->addsheet('FBB Centiloid');
my @drow;
if($internos){
	@drow = split ',', "Subject,Interno,Date,SUVR,CL,QC";
}else{
	@drow = split ',', "Subject,Date,SUVR,CL,QC";
}
$workbook->addrow(\@drow);
foreach my $sbj (sort keys %guys){
	if(exists($guys{$sbj}) and exists($guys{$sbj}{'SUVR'}) and $guys{$sbj}{'SUVR'} and ($guys{$sbj}{'SUVR'} ne 'null')){
		 if($internos){
			 @drow = split ',', "$sbj,$guys{$sbj}{'INTERNO'},$guys{$sbj}{'DATE'},$guys{$sbj}{'SUVR'},$guys{$sbj}{'CL'},$guys{$sbj}{'QC'}";
		}else{
			@drow = split ',', "$sbj,$guys{$sbj}{'DATE'},$guys{$sbj}{'SUVR'},$guys{$sbj}{'CL'},$guys{$sbj}{'QC'}";
		}
		$workbook->addrow(\@drow);
	}
}
$workbook->close();
unlink $guide;
close DBG unless $debug;

