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
#
use strict; use warnings;
use NEURO4 qw(get_subjects check_fs_subj load_project print_help shit_done check_or_make);
use FSMetrics qw(fs_file_metrics);
use File::Basename qw(basename);
use File::Temp qw( :mktemp tempdir);
use File::Path qw(make_path);
use Cwd qw(cwd);
use Text::CSV qw( csv );
use Spreadsheet::Write;
use Data::Dump qw(dump);

my $localdir = cwd;
my $info_page = $ENV{PIPEDIR}.'/lib/info_page_mri.csv';
my $guide;
my $ofile;
my $internos;
# print help if called without arguments
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-g/) { $guide = shift; chomp($guide);}
    if (/^-i/) { $internos = shift; chomp($internos);}
    if (/^-o/) { $ofile = shift; chomp($ofile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/fs_metrics.hlp'; exit;}
}
# Este es el proyecto en XNAT. Es obligatorio.
my $study = shift;
my $tmp_dir = $ENV{'TMPDIR'};
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/fs_metrics.hlp'; exit;}
#my %std = load_project($study);
#my $db = $std{DATA}.'/'.$study.'_mri.csv';
#my $fsout = $std{DATA}.'/fsrecon';
#check_or_make($fsout);
#my @plist = get_subjects($db);
#my $subj_dir = $ENV{'SUBJECTS_DIR'};
$ofile = $study.'_fsmetrics.xls';
my %guys;
my $subjects_list = mktemp($tmp_dir.'/sbjsfileXXXXX');
# Get subject list
my $order = 'xnatapic list_subjects --project_id '.$study.' --label > '.$subjects_list;
system($order);
#while read -r line; do stag=$(echo ${line} | awk -F"," '{print $1}'); slab=$(echo ${line} | awk -F"," '{print $2}'); xtag=$(xnatapic list_experiments --project_id facehbi --subject_id ${stag} --modality MRI --date); echo "${slab},${xtag}"; done < xnat_subjects.csv > exps_withdate.csv
#while read -r line; do xp=$(echo ${line} | awk -F"," '{print $2}'); slab=$(echo ${line} | awk -F"," '{print $1}'); mkdir -p test_xnatfs/${xp}/stats; xnatapic get_fsresults --experiment_id ${xp} --all-stats test_xnatfs/${xp}/stats; done < exps_withdate.csv
#my $exps_withdate = mktemp("expsfile.XXXXX");
open SLF, "<$subjects_list";
while(<SLF>){
	my ($stag, $slab) = /(.*),(.*)/;
	chomp($slab);
	$guys{$slab}{'XNATSBJ'} = $stag;
	my $xnat_order = 'xnatapic list_experiments --project_id '.$study.' --subject_id '.$stag.' --modality MRI --date';
	my $xtag = qx/$xnat_order/;
	chomp($xtag);
	my ($xnam, $xdate) = $xtag =~ /(.*),(.*)/;
	$guys{$slab}{'XNATEXP'} = $xnam;
	$xdate =~ s/-/./g;
	$guys{$slab}{'DATE'} = $xdate;
}
close SLF;
unlink $subjects_list;
#while read -r line; do xp=$(echo ${line} | awk -F"," '{print $2}'); slab=$(echo ${line} | awk -F"," '{print $1}'); mkdir -p test_xnatfs/${xp}/stats; xnatapic get_fsresults --experiment_id ${xp} --all-stats test_xnatfs/${xp}/stats; done < exps_withdate.csv
my $fsoutput = tempdir(TEMPLATE => $tmp_dir.'/fsout.XXXXX', CLEANUP => 1);
my @fspnames;
foreach my $plab (sort keys %guys){
	push @fspnames, $plab;
	my $outdir = $fsoutput.'/'.$plab.'/stats';
	make_path $outdir; 
	$order = 'xnatapic get_fsresults --experiment_id '.$guys{$plab}{'XNATEXP'}.' --all-stats '.$outdir;
	system($order);
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
	$guide = mktemp("guide_data.XXXXX");
	open GDF, ">$guide";
	if ($internos){
		open IIF, "<$internos";
		while (<IIF>){
			if (/(.*),\d{8}$/){
				my ($sbj, $interno) = /(.*),\d{8}$/;
				$guys{$sbj}{'INTERNO'} = $interno;
			}
		}
		close IIF;
		print GDF "Subject,Interno,Date\n";
		foreach my $plab (sort keys %guys){
			print GDF "$plab,$guys{$plab}{'INTERNO'},$guys{$plab}{'DATE'}\n";
		}
	}else{
		print GDF "Subject,Date\n";
		foreach my $plab (sort keys %guys){
			print GDF "$plab,$guys{$plab}{'DATE'}\n";
		}
	}
	close GDF;
}

my $fsqcfile = $fsoutput.'/fsqc.csv';
#my $fsqcfile = $localdir.'/fsqc.csv';
#dump $fsqcfile;
$order = 'xnatapic get_fsqc --project_id '.$study.' --output '.$fsqcfile;
system($order);
#$order = 'sed -i \'s/"//g;s/ //g;1iSubject,QC,Notes\' '.$fsqcfile;
#system($order);
my @fsqc_data;
open QCF, "<$fsqcfile";
while (<QCF>) {
	my ($sbj, $qcok, $qcnotes) = /(.*), "(.*)", "(.*)"/;
	$qcok =~ tr/ODILg/odilG/;
	$guys{$sbj}{'FSQC'} = $qcok;
	$guys{$sbj}{'Notes'} = $qcnotes;
}
close QCF;
my $info = csv (in => $info_page);
my $workbook = Spreadsheet::Write->new(file => $ofile, sheet => 'Info');
for my $i (0 .. $#{$info}) {
	my $row = $info->[$i];
	$workbook->addrow($row);
}

#$info = csv (in => $fsqcfile);
$workbook->addsheet('FSQC');
#for my $i (0 .. $#{$info}) {
#	my $row = $info->[$i];
my @qcrow = split ',', "Subject,FSQC,Notes";
$workbook->addrow(\@qcrow);
foreach my $sbj (sort keys %guys){
	if (exists($guys{$sbj}) and exists($guys{$sbj}{'FSQC'}) and $guys{$sbj}{'FSQC'}){
		if (exists($guys{$sbj}{'Notes'}) and $guys{$sbj}{'Notes'}){
			@qcrow = split ',', "$sbj,$guys{$sbj}{'FSQC'},$guys{$sbj}{'Notes'}";
		}else{
			@qcrow = split ',', "$sbj,$guys{$sbj}{'FSQC'}";
		}
		$workbook->addrow(\@qcrow);
	}
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
	unlink $tmpf;
}
$workbook->close();


#my $zfile = $fsoutput.'/'.$study."_mri_results.tgz";
#system("tar czf $zfile $fsresdir");
#shit_done basename($ENV{_}), $study, $zfile;

