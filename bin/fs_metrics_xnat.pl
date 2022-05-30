#!/usr/bin/perl

# Copyright 2019 - 2022 O. Sotolongo <asqwerty@gmail.com>

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
use NEURO4 qw(get_subjects check_fs_subj load_project print_help shit_done check_or_make getLoggingTime);
use FSMetrics qw(fs_file_metrics);
use XNATACE qw(xget_session xget_subjects xget_mri xget_exp_data xget_fs_qc xget_fs_allstats);
use File::Basename qw(basename);
use File::Temp qw( :mktemp tempdir);
use File::Path qw(make_path);
use File::Copy;
use Cwd qw(cwd);
use Text::CSV qw( csv );
use Spreadsheet::Write;
use Data::Dump qw(dump);

my $localdir = cwd;
my $info_page = $ENV{PIPEDIR}.'/lib/info_page_mri.csv';
my $guide;
my $internos;
my $debug = 0;
my $alt = 0;
my $csvdir; my $savdir;
# print help if called without arguments
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-g/) { $guide = shift; chomp($guide);}
    if (/^-i/) { $internos = shift; chomp($internos);}
    if (/^-a/) { $alt = 1; }
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/fs_metrics.hlp'; exit;}
}
# Este es el proyecto en XNAT. Es obligatorio.
my $study = shift;
my $tmp_dir = $ENV{'TMPDIR'};
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/fs_metrics.hlp'; exit;}
unless ($debug) {
	my $logfile = 'fs_metrics_xnat_'.getLoggingTime().'.log';
	open STDOUT, ">$logfile" or die "Can't redirect stdout";
	open STDERR, ">&STDOUT" or die "Can't dup stdout";
	open DBG, ">$logfile";
}
my $ofile = $study.'_fsmetrics_'.getLoggingTime().'.xls';
my %xconf = xget_session();
my %subjects = xget_subjects($xconf{'HOST'}, $xconf{'JSESSION'}, $study);
my %inbreed;
foreach my $key (sort keys %subjects){ $inbreed{$subjects{$key}{'label'}} = $key;}
foreach my $sbj (sort keys %subjects){
	$subjects{$sbj}{'experiment'} = xget_mri($xconf{'HOST'}, $xconf{'JSESSION'}, $study, $sbj);
	$subjects{$sbj}{'DATE'} = xget_exp_data($xconf{'HOST'}, $xconf{'JSESSION'}, $subjects{$sbj}{'experiment'}, 'date');
}
#dump %subjects; exit;
my $fsoutput = tempdir(TEMPLATE => $tmp_dir.'/fsout.XXXXX', CLEANUP => 1);
print "###############################################\n";
print "### $fsoutput ### \n";
print "###############################################\n";
my @fspnames;
foreach my $plab (sort keys %inbreed){
	push @fspnames, $plab;
	my $outdir = $fsoutput.'/'.$plab.'/stats';
	make_path $outdir; 
	xget_fs_allstats($xconf{'HOST'}, $xconf{'JSESSION'}, $subjects{$inbreed{$plab}}{'experiment'}, $outdir);
}

my %stats = fs_file_metrics();
my $fslist = join ' ', @fspnames;
$ENV{'SUBJECTS_DIR'} = $fsoutput;
my $fsout = $fsoutput.'/fsrecon';
make_path $fsout;
foreach my $stat (sort keys %stats) {
	if(exists($stats{$stat}{'active'}) && $stats{$stat}{'active'}){
		(my $order = $stats{$stat}{'order'}) =~ s/<list>/$fslist/;
		 $order =~ s/<fs_output>/$fsout/;
		system("$order");
		(my $opatt = $stat) =~ s/_/./g;
		$opatt =~ s/(.*)\.rh$/rh\.$1/;
		$opatt =~ s/(.*)\.lh$/lh\.$1/;
		$order = 'sed \'s/\t/,/g; s/^Measure:volume\|^'.$opatt.'/Subject/\' '.$fsout.'/'.$stat.'.txt > '.$fsout.'/'.$stat.'.csv'."\n";
		system($order);
	}
}

unless ($guide) {
	$guide = mktemp($tmp_dir.'/guide_data.XXXXX');
	open GDF, ">$guide";
	if ($internos){
		open IIF, "<$internos";
		while (<IIF>){
			if (/.*,\d{8}$/){
				my ($sbj, $interno) = /(.*),(\d{8})$/;
				if(exists($inbreed{$sbj}) and $inbreed{$sbj}){
					$subjects{$inbreed{$sbj}}{'INTERNO'} = $interno;
				}
			}
		}
		close IIF;
		print GDF "Subject,Interno,Date\n";
		foreach my $plab (sort keys %inbreed){
			if (exists($subjects{$inbreed{$plab}}{'INTERNO'}) and exists($subjects{$inbreed{$plab}}{'DATE'})){
				print GDF "$plab,$subjects{$inbreed{$plab}}{'INTERNO'},$subjects{$inbreed{$plab}}{'DATE'}\n";

			}
		}
	}else{
		print GDF "Subject,Date\n";
		foreach my $plab (sort keys %inbreed){
			print GDF "$subjects{$inbreed{$plab}}{'label'},$subjects{$inbreed{$plab}}{'DATE'}\n";
		}
	}
	close GDF;
}

my $fsqcfile = $fsoutput.'/fsqc.csv';
foreach my $sbj (sort keys %subjects){
	if(exists($subjects{$sbj}{'experiment'}) and $subjects{$sbj}{'experiment'}){
		my %tmp_hash = xget_fs_qc($xconf{'HOST'}, $xconf{'JSESSION'}, $subjects{$sbj}{'experiment'});
		$tmp_hash{'rating'} =~ tr/ODILg/odilG/;
		$subjects{$sbj}{'FSQC'} = $tmp_hash{'rating'};
		$subjects{$sbj}{'Notes'} = $tmp_hash{'notes'};
	}
}
my $info = csv (in => $info_page);
my $workbook = Spreadsheet::Write->new(file => $ofile, sheet => 'Info');
for my $i (0 .. $#{$info}) {
	my $row = $info->[$i];
	$workbook->addrow($row);
}

$workbook->addsheet('FSQC');
my @qcrow; 
if ($internos) {
	@qcrow = split ',', "Subject,Interno,Date,FSQC,Notes";
}else{
	@qcrow = split ',', "Subject,Date,FSQC,Notes";
}
$workbook->addrow(\@qcrow);
foreach my $sbj (sort keys %inbreed){
	if (exists($subjects{$inbreed{$sbj}}) and exists($subjects{$inbreed{$sbj}}{'FSQC'}) and $subjects{$inbreed{$sbj}}{'FSQC'}){
		if (exists($subjects{$inbreed{$sbj}}{'Notes'}) and $subjects{$inbreed{$sbj}}{'Notes'}){
			if ($internos){
				@qcrow = split ',', "$subjects{$inbreed{$sbj}}{'label'},$subjects{$inbreed{$sbj}}{'INTERNO'},$subjects{$inbreed{$sbj}}{'DATE'},$subjects{$inbreed{$sbj}}{'FSQC'},$subjects{$inbreed{$sbj}}{'Notes'}";
			}else{
				@qcrow = split ',', "$subjects{$inbreed{$sbj}}{'label'},$subjects{$inbreed{$sbj}}{'DATE'},$subjects{$inbreed{$sbj}}{'FSQC'},$subjects{$inbreed{$sbj}}{'Notes'}";
			}
		}else{
			if ($internos){
				@qcrow = split ',', "$subjects{$inbreed{$sbj}}{'label'},$subjects{$inbreed{$sbj}}{'INTERNO'},$subjects{$inbreed{$sbj}}{'DATE'},$subjects{$inbreed{$sbj}}{'FSQC'}";
			}else{
				@qcrow = split ',', "$subjects{$inbreed{$sbj}}{'label'},$subjects{$inbreed{$sbj}}{'DATE'},$subjects{$inbreed{$sbj}}{'FSQC'}";
			}
		}
		$workbook->addrow(\@qcrow);
	}
}

if ($alt) {
	$csvdir = $study.'_fsmetrics_csv_'.getLoggingTime();
	$savdir = $study.'_fsmetrics_spss_'.getLoggingTime();
	make_path $csvdir;
	make_path $savdir;
}

my $rwtmpout = $fsoutput.'/tmps';
make_path $rwtmpout;
opendir (DIR, $fsout);
my @ifiles = grep(/\.csv/, readdir(DIR));
close DIR;
foreach my $ifile (@ifiles){
	my $tmpf = $rwtmpout.'/tmp_'.$ifile;
	my $order = 'join -t, -j 1 '.$guide.' '.$fsout.'/'.$ifile.' > '.$tmpf;
	system($order);
	my $idata = csv (in => $tmpf); # as array of array
	(my $shname = $ifile) =~ s/\.csv$//;
	$workbook->addsheet($shname);
	for my $i (0 .. $#{$idata}) {
		my $row = $idata->[$i];
		$workbook->addrow($row);
	}
	if ($alt) {
		my $csvfile = $csvdir.'/'.$ifile;
		copy $tmpf, $csvfile;
		my $rscript = mktemp($fsoutput.'/rtmpscript.XXXXX');
		open ORS, ">$rscript";
		print ORS 'library("haven")'."\n";
		print ORS 'read.csv("'.$tmpf.'") -> w'."\n";
		my $savfile = $savdir.'/'.$shname.'.sav';
		print ORS 'write_sav(w,"'.$savfile.'")'."\n";
		close ORS;
		system("Rscript $rscript");
		unlink $rscript;
	}
	unlink $tmpf;
}
$workbook->close();

if($alt){
	my $zfile = $study."_fsmetrics.tgz";
	system("tar czf $zfile $csvdir $savdir");
	shit_done basename($ENV{_}), $study, $zfile;
}
unlink $guide;
close DBG unless $debug;
