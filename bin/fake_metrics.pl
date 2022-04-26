#!/usr/bin/perl
# Copyright 2021 O. Sotolongo <asqwerty@gmail.com>
use strict; use warnings;
use FSMetrics qw(tau_rois);
use NEURO4 qw(print_help load_project cut_shit check_pet);
use Data::Dump qw(dump);
my $cfile="";
my @rois = tau_rois();
my $style = "";
@ARGV = ("-h") unless @ARGV;

while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-r/) {$style = shift; chomp($style);}
}

my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/pet_metrics.hlp'; exit;}
my %std = load_project($study);
my $w_dir=$std{'WORKING'};
my $data_dir=$std{'DATA'};
my $db = $data_dir.'/'.$study.'_mri.csv';
our @subjects = cut_shit($db, $data_dir."/".$cfile);
#my @subs = ("pvc", "unc","mtc");
if($style){@rois = tau_rois($style);}
my $norm = @rois; 
my %measures;
foreach my $subject (@subjects){
#	my %spet = check_pet($std{'DATA'},$subject,$tracer);
	my $fake_tau = $w_dir.'/'.$subject.'_tau.nii.gz';
	if( -e $fake_tau ){
		my $ifile = $w_dir.'/'.$subject.'_unc.csv';
		open IDF, "<$ifile" or next;
		while (<IDF>){
			if(/\d\t\d+\.*\d*/){
				my ($index, $tau) = /(\d)\t(\d+\.*\d*)/;
				$measures{$subject}[$index-1] = $tau;
			}
		} 
		close IDF;
	}
}
#dump %measures;

my $ofile = $data_dir.'/'.$study."_fbb_suvr_fake.csv";
print "Writing $ofile\n";
open ODF, ">$ofile";
print ODF "Subject";
foreach my $roi (@rois){
	print ODF ", $roi";
}
print ODF "\n";
foreach my $subject (@subjects){
	if(exists($measures{$subject}) && exists($measures{$subject}[$norm]) && $measures{$subject}[$norm]){
		print ODF "$subject";
		for (my $i=0; $i<$norm; $i++){
			my $mean = 0;
			if(exists($measures{$subject}[$i]) && $measures{$subject}[$i]){
				$mean = $measures{$subject}[$i]/$measures{$subject}[$norm];
			}
			print ODF ",$mean";
		}
		print ODF "\n";
	}
}
close ODF;

