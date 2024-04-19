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
use XNATACE qw(xget_session xget_subjects xget_pet xget_exp_data xget_pet_data);
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
# Get subject list
#my %xconfig = xget_session();
my %guys = xget_subjects($study);
my %inbreed;
foreach my $key (sort keys %guys) { $inbreed{$guys{$key}{'label'}} = $key; }
foreach my $stag (sort keys %guys){
	$guys{$stag}{'XNATEXP'} = xget_pet($study, $stag);
	if($guys{$stag}{'XNATEXP'}){
		$guys{$stag}{'DATE'} = xget_exp_data($guys{$stag}{'XNATEXP'}, 'date');
	}
}
#dump %guys; exit;
# to guide or not to guide?
unless ($guide) {
	$guide = mktemp($tmp_dir.'/guide_data.XXXXX');
	open GDF, ">$guide";
	if ($internos){
		open IIF, "<$internos";
		while (<IIF>){
			if (/.*,\d{8}$/){
				my ($sbj, $interno) = /(.*),(\d{8})$/;
				if(exists($inbreed{$sbj}) and $inbreed{$sbj}){
					$guys{$inbreed{$sbj}}{'INTERNO'} = $interno;
				}
			}
		}
		close IIF;
		print GDF "Subject,Interno,Date\n";
		foreach my $plab (sort keys %inbreed){
			if (exists($guys{$inbreed{$plab}}{'INTERNO'}) and exists($guys{$inbreed{$plab}}{'DATE'})){
				print GDF "$plab,$guys{$inbreed{$plab}}{'INTERNO'},$guys{$inbreed{$plab}}{'DATE'}\n";
				#print "$plab,$guys{$plab}{'INTERNO'},$guys{$plab}{'DATE'}\n";
			}
		}
	}else{
		print GDF "Subject,Date\n";
		foreach my $plab (sort keys %inbreed){
			if(exists($guys{$inbreed{$plab}}) and exists($guys{$inbreed{$plab}}{'DATE'}) and $guys{$inbreed{$plab}}{'DATE'}){ 
				print GDF "$plab,$guys{$inbreed{$plab}}{'DATE'}\n"; 
			}
		}
	}
	close GDF;
}
foreach my $sbj (sort keys %guys) {
	if(exists($guys{$sbj}{'XNATEXP'}) and $guys{$sbj}{'XNATEXP'}){
		my %tmp_hash = xget_pet_data($guys{$sbj}{'XNATEXP'});
		if(%tmp_hash){
			foreach my $tmp_var (sort keys %tmp_hash){
				$guys{$sbj}{$tmp_var} = $tmp_hash{$tmp_var} unless $tmp_var eq '_';
			}
		}
	}
}
# make xls file
# info first
#dump %guys; exit;
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
	@drow = split ',', "Subject,Interno,Date,SUVR,Centiloid,QC";
}else{
	@drow = split ',', "Subject,Date,SUVR,Centiloid,QC";
}
$workbook->addrow(\@drow);
foreach my $sbj (sort keys %inbreed){
	if(exists($guys{$inbreed{$sbj}}) and exists($guys{$inbreed{$sbj}}{'surv'}) and $guys{$inbreed{$sbj}}{'surv'} and ($guys{$inbreed{$sbj}}{'surv'} ne 'null')){
		 if($internos){
			 @drow = split ',', "$sbj,$guys{$inbreed{$sbj}}{'INTERNO'},$guys{$inbreed{$sbj}}{'DATE'},$guys{$inbreed{$sbj}}{'surv'},$guys{$inbreed{$sbj}}{'cl'},$guys{$inbreed{$sbj}}{'qa'}";
		}else{
			@drow = split ',', "$sbj,$guys{$inbreed{$sbj}}{'DATE'},$guys{$inbreed{$sbj}}{'surv'},$guys{$inbreed{$sbj}}{'cl'},$guys{$inbreed{$sbj}}{'qa'}";
		}
		#dump @drow;
		$workbook->addrow(\@drow);
	}
}
$workbook->close();
unlink $guide;
close DBG unless $debug;

