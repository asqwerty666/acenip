#!/usr/bin/perl
#Copyright 2021 O. Sotolongo <asqwerty@gmail.com>

use strict;
use warnings;
use NEURO4 qw(load_project print_help populate check_or_make);

my $prj;
my $xprj;
my $tmpdir; 
chomp($tmpdir = `mktemp -d /tmp/fstar.XXXXXX`);
my $guide = $tmpdir."/xnat_guys.list";
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-p/) { $prj = shift; chomp($prj);}
    if (/^-x/) { $xprj = shift; chomp($xprj);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/xnat_pull.hlp'; exit;}
}
$xprj = $prj unless $xprj;
my %std = load_project($prj);
my $order = "xnatapic list_subjects --project_id ".$xprj." --label > ".$std{'DATA'}."/xnat_subjects.list";
print "Getting XNAT subject list\n";
system($order);
$order = "for x in `awk -F\",\" {'print \$1'} xnat_subjects.list`; do e=\$(xnatapic list_experiments --project_id ".$xprj." --subject_id \${x} --modality MRI); if [[ \${e} ]]; then echo \"\${x},\${e}\"; fi; done > ".$std{'DATA'}."/xnat_subject_mri.list";
print "Getting experiments\n";
system($order);
my $proj_file = $std{'DATA'}.'/'.$prj.'_mri.csv';
$order = "sed 's/;/,/g' ".$proj_file." > ".$tmpdir."/all_mri.list;"; 
$order.= "sort -t, -k 2 ".$tmpdir."/all_mri.list > ".$tmpdir."/all_mri_sorted.list;";
$order.= "join -t, xnat_subjects.list xnat_subject_mri.list > ".$tmpdir."/tmp_mri.list;";
$order.= "sort -t, -k 2 ".$tmpdir."/tmp_mri.list > ".$tmpdir."/xnat_tmp_mri_sorted.list;";
$order.= "join -t, -j 2 ".$tmpdir."/all_mri_sorted.list ".$tmpdir."/xnat_tmp_mri_sorted.list  > ".$tmpdir."/xnat_guys.list";
print "Sorting, joining, keeping shit together\n";
system($order);
print "OK, now I'm going on\nDownloading and extracting\n";
open IDF, "<$guide" or die "No such file or directory\n";
while(<IDF>){
	my ($pid, $imgid, $xsubj, $xexp) = /(.*),(.*),(.*),(.*)/;
	my $fsdir = $ENV{'SUBJECTS_DIR'}."/".$prj."_".$imgid;
	unless ( -d $fsdir){
		my $tfsdir = $tmpdir."/".$prj."_".$imgid;
		mkdir $tfsdir;
		my $xorder = "xnatapic get_fsresults --experiment_id ".$xexp." --all-tgz ".$tfsdir;
		print "$xorder\n";
		system($xorder);
		mkdir $fsdir;
		my $order = "tar xzvf ".$tfsdir."/*.tar.gz -C ".$fsdir."/ --transform=\'s/".$xsubj."//\' --exclude=\'fsaverage\'";
		print "$order\n";
		system($order);
	}
}
$order = "rm -rf ".$tmpdir;
system($order);
