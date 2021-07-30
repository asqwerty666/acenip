#!/usr/bin/perl
#Copyright 2021 O. Sotolongo <asqwerty@gmail.com>

use strict;
use warnings;
use NEURO4 qw(load_project print_help populate check_or_make);

my $prj;
my $xprj;
my $tmpdir; 
my $STDOLD;
my $ofile = '';
chomp($tmpdir = `mktemp -d /tmp/petcl.XXXXXX`);
my $guide = $tmpdir."/xnat_guys.list";
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-p/) { $prj = shift; chomp($prj);}
    if (/^-x/) { $xprj = shift; chomp($xprj);}
    if (/^-o/) { $ofile = shift; chomp($ofile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/xnat_pull.hlp'; exit;}
}
$xprj = $prj unless $xprj;
#my %std = load_project($prj);
#my $proj_file = $std{'DATA'}.'/'.$prj.'_mri.csv';
#print "Wait a minute, getting XNAT subject list\n";
my $order = "xnatapic list_subjects --project_id ".$xprj." --label > ".$tmpdir."/xnat_subjects.list";
system($order);
$order = "sort -t, -k 1 ".$tmpdir."/xnat_subjects.list > ".$tmpdir."/xnat_subjects_sorted.list";
system($order);
#print "Getting PET data now\n";
$order = "xnatapic get_registration_report --project_id ".$xprj." --output ".$tmpdir."/xnat_pet_results.csv".' 1>/dev/null';
system($order);
#print "Sorting, joining, keeping shit together\n";
$order = "awk -F\",\" '{print \$2\",\"\$6\",\"\$7}' ".$tmpdir."/xnat_pet_results.csv | sed 's/\"//g' | tail -n +2 | sort -t, -k 1 > ".$tmpdir."/pet.results";
system($order);
open STDOUT, ">$ofile" unless not $ofile;
$order = "join -t, ".$tmpdir."/xnat_subjects_sorted.list ".$tmpdir."/pet.results | sort -t, -k 2 | awk -F\",\" '{if (\$3) print \$2\";\"\$3\";\"\$4}' | sed '1iSubject;SUVR;Centiloid'";
system($order);
#$order = "sed 's/;/,/g' ".$proj_file." | sort -t, -k 2 > ".$tmpdir."/all_pet.list;"; 
#$order.= "join -t, -j 2 ".$tmpdir."/all_pet.list ".$tmpdir."/xnat_tmp_pet_sorted.list | awk -F\",\" '{print \$2\";\"\$4\";\"\$5}' | sed '1iSubject;SUVR;Centiloid' > ".$std{'DATA'}."/xnat_fbb_cl.csv";
#system($order);
$order = "rm -rf ".$tmpdir;
system($order);
