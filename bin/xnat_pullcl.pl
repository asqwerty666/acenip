#!/usr/bin/perl
#Copyright 2021 O. Sotolongo <asqwerty@gmail.com>

use strict;
use warnings;
use NEURO4 qw(load_project print_help populate check_or_make);
use XNATACE qw(xget_session xget_subjects xget_pet xget_pet_data xget_exp_data xget_sbj_data);
use File::Temp qw(tempdir);
use Data::Dump qw(dump);
my $prj;
my $xprj;
my $STDOLD;
my $ofile = '';
my $tmp_dir = $ENV{'TMPDIR'};
my $tmpdir = tempdir(TEMPLATE => $tmp_dir.'/petcl.XXXXX', CLEANUP => 1);
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
my %std = load_project($prj);
if(exists($std{'XNAME'}) and $std{'XNAME'}){
	$xprj = $std{'XNAME'};
}
#my %xconfig = xget_session();
# Saco los sujetos del proyecto
#print "Getting XNAT subject list\n";
#my $jid = $xconfig{'JSESSION'};
my %subjects = xget_subjects($xprj);
#print "Getting PET data now\n";
my %spets;
foreach my $subject (sort keys %subjects){
	$spets{$subject}{'experiments'} = [ xget_pet($xprj, $subject) ];
}
my %experiments;
foreach my $subject (sort keys %spets){
	if(exists($spets{$subject}) and $spets{$subject}){
		if(exists($spets{$subject}{'experiments'}) and $spets{$subject}{'experiments'}){
			$spets{$subject}{'label'} = xget_sbj_data($subject, 'label');
			foreach my $experiment (@{$spets{$subject}{'experiments'}}){
				my %tmp_hash = xget_pet_data($experiment);
				if (%tmp_hash){
					foreach my $tmp_var (sort keys %tmp_hash){
						$experiments{$experiment}{$tmp_var} = $tmp_hash{$tmp_var} unless $tmp_var eq '_';
					}
				}
			}
		}
	}		
}
#dump %spets;
#dump %experiments;
#print "I got the data!\n";
open STDOUT, ">$ofile" unless not $ofile;
print "Subject,Date,SUVR,Centiloid\n";
foreach my $subject (sort keys %spets) {
	if(exists($spets{$subject}{'experiments'})){
		foreach my $experiment (@{$spets{$subject}{'experiments'}}){
			if (exists($experiments{$experiment})) {
				print STDERR "$subject -> $experiment\n";
				my $date = xget_exp_data($experiment, 'date');
				print "$spets{$subject}{'label'},$date,$experiments{$experiment}{'surv'},$experiments{$experiment}{'cl'}\n";
			}
		}
	}
}
close STDOUT;
