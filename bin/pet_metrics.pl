#!/usr/bin/perl
# Copyright 2021 O. Sotolongo <asqwerty@gmail.com>
use strict; use warnings;
use FSMetrics qw(pet_rois);
use NEURO4 qw(print_help load_project cut_shit);
use Data::Dump qw(dump);
my $cfile="";
my @rois = pet_rois();
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
my $db = $data_dir.'/'.$study.'_pet.csv';
our @subjects = cut_shit($db, $data_dir."/".$cfile);
my @subs = ("pvc", "unc");
if($style){@rois = pet_rois($style);}
my $norm = @rois; 
print "$norm\n";
my %measures;
foreach my $subject (@subjects){
	foreach my $msub (@subs){
		my $ifile = $w_dir.'/'.$subject.'_'.$msub.'.csv';
		open IDF, "<$ifile" or next;
		while (<IDF>){
			if(/\d+\t\d+\.*\d*/){
				my ($index, $tau) = /(\d+)\t(\d+\.*\d*)/;
				$measures{$subject}{$msub}[$index-1] = $tau;
			}
		} 
		close IDF;
	}
}
dump %measures;

foreach my $msub (@subs){
	my $ofile = $data_dir.'/'.$study."_pet".($style?"_".$style:"")."_suvr_".$msub.".csv";
	print "Writing $ofile\n";
	open ODF, ">$ofile";
	print ODF "Subject";
	foreach my $roi (@rois){
		print ODF ", $roi";
	}
	print ODF "\n";
	foreach my $subject (@subjects){
		if(exists($measures{$subject}) && exists($measures{$subject}{$msub}) && exists($measures{$subject}{$msub}[$norm]) && $measures{$subject}{$msub}[$norm]){
			print ODF "$subject";
			for (my $i=0; $i<$norm; $i++){
				my $mean = 0;
				if(exists($measures{$subject}{$msub}[$i]) && $measures{$subject}{$msub}[$i]){
					$mean = $measures{$subject}{$msub}[$i]/$measures{$subject}{$msub}[$norm];
				}
				print ODF ", $mean";
			}
			print ODF "\n";
		}
	}
	close ODF;
}

