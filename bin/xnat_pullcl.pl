#!/usr/bin/perl
#Copyright 2021 O. Sotolongo <asqwerty@gmail.com>

use strict;
use warnings;
use NEURO4 qw(load_project print_help populate check_or_make);
use File::Temp qw(tempdir);
my $prj;
my $xprj;
my $tmpdir; 
my $STDOLD;
my $ofile = '';
#my $tmp_dir = $ENV{'TMPDIR'};
#my $tmpdir = tempdir(TEMPLATE => $tmp_dir.'/petcl.XXXXX', CLEANUP => 1);
#my $guide = $tmpdir."/xnat_guys.list";
my $with_date = 0;
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-p/) { $prj = shift; chomp($prj);}
    if (/^-x/) { $xprj = shift; chomp($xprj);}
    if (/^-o/) { $ofile = shift; chomp($ofile);}
    if (/^-d/) { $with_date = 1; }
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/xnat_pullcl.hlp'; exit;}
}
$xprj = $prj unless $xprj;
die "Should supply project name\n" unless $prj;
#my %std = load_project($prj);
#my $proj_file = $std{'DATA'}.'/'.$prj.'_mri.csv';
#print "Wait a minute, getting XNAT subject list\n";
my $tmp_dir = $ENV{'TMPDIR'};
$tmpdir = tempdir(TEMPLATE => $tmp_dir.'/petcl.XXXXX', CLEANUP => 0);
#print STDERR "Working at $tmpdir\n";
my $order = "xnatapic list_subjects --project_id ".$xprj." --label > ".$tmpdir."/xnat_subjects.list";
system($order);
$order = "sort -t, -k 1 ".$tmpdir."/xnat_subjects.list > ".$tmpdir."/xnat_subjects_sorted.list";
system($order);
#print "Getting PET data now\n";
$order = "xnatapic get_registration_report --project_id ".$xprj." --output ".$tmpdir."/xnat_pet_results.csv".' 1>/dev/null';
system($order);
#print "Sorting, joining, keeping shit together\n";
#
if($with_date){
	my $ptfile = $tmpdir.'/pet.results.tmp';
	$order = "awk -F\",\" '{print \$2\",\"\$3\",\"\$6\",\"\$7}' ".$tmpdir."/xnat_pet_results.csv | sed 's/\"//g' | tail -n +2 | sort -t, -k 1 > ".$ptfile;
	system($order);
	open IDF, "<$ptfile" or die "No temporary file at all\n";
	my $optfile = $tmpdir.'/pet.results';
	open ODF, ">$optfile" or die "Could not open output file\n";
	while(<IDF>){
		my ($sbj, $pxp, $suvr, $cl) = /(.*),(.*),(.*),(.*)/;
		#xnatapic list_experiments --project_id f5cehbi --subject_id XNAT_S00086 --modality PET --date | awk -F',' '{print $2}'
		my $sorder = 'xnatapic list_experiments --project_id '.$xprj.' --subject_id '.$sbj." --experiment_id ".$pxp." --modality PET --date | awk -F',' '{print \$2}'";
		my ($xdate) = qx/$sorder/;
		chomp $xdate;
		print ODF "$sbj,$xdate,$suvr,$cl\n";
	}
	close ODF;
	close IDF;
}else{
	$order = "awk -F\",\" '{print \$2\",\"\$6\",\"\$7}' ".$tmpdir."/xnat_pet_results.csv | sed 's/\"//g' | tail -n +2 | sort -t, -k 1 > ".$tmpdir."/pet.results";
	system($order);
}
open STDOUT, ">$ofile" unless not $ofile;
if($with_date){
	$order = "join -t, ".$tmpdir."/xnat_subjects_sorted.list ".$tmpdir."/pet.results | sort -t, -k 2 | awk -F\",\" '{if (\$3) print \$2\";\"\$3\";\"\$4\";\"\$5}' | sed '1iSubject;Date;SUVR;Centiloid'";
}else{
        $order = "join -t, ".$tmpdir."/xnat_subjects_sorted.list ".$tmpdir."/pet.results | sort -t, -k 2 | awk -F\",\" '{if (\$3) print \$2\";\"\$3\";\"\$4}' | sed '1iSubject;SUVR;Centiloid'";
}
system($order);
#$order = "sed 's/;/,/g' ".$proj_file." | sort -t, -k 2 > ".$tmpdir."/all_pet.list;"; 
#$order.= "join -t, -j 2 ".$tmpdir."/all_pet.list ".$tmpdir."/xnat_tmp_pet_sorted.list | awk -F\",\" '{print \$2\";\"\$4\";\"\$5}' | sed '1iSubject;SUVR;Centiloid' > ".$std{'DATA'}."/xnat_fbb_cl.csv";
#system($order);
$order = "rm -rf ".$tmpdir;
system($order);
