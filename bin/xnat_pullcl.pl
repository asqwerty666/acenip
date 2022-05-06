#!/usr/bin/perl
#Copyright 2021 O. Sotolongo <asqwerty@gmail.com>

use strict;
use warnings;
use NEURO4 qw(load_project print_help populate check_or_make);
use XNATACE qw(xconf xget_conf xget_session xget_subjects xget_pet xget_pet_data xget_exp_data xget_sbj_data);
use File::Temp qw(tempdir);
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
my %xconfig = xget_conf();
# Saco los sujetos del proyecto
#print "Getting XNAT subject list\n";
my $jid = xget_session();
my %subjects = xget_subjects($xconfig{'HOST'}, $jid, $xprj);
#print "Getting PET data now\n";
my %spets;
foreach my $subject (sort keys %subjects){
	$spets{$subject}{'experiment'} = xget_pet($xconfig{'HOST'}, $jid, $xprj, $subject);
}
foreach my $subject (sort keys %spets){
	if(exists($spets{$subject}) and $spets{$subject}){
		if(exists($spets{$subject}{'experiment'}) and $spets{$subject}{'experiment'}){
			$spets{$subject}{'label'} = xget_sbj_data($xconfig{'HOST'}, $jid, $subject, 'label');
			my %tmp_hash = xget_pet_data($xconfig{'HOST'}, $jid, $spets{$subject}{'experiment'});
			if (%tmp_hash){
				foreach my $tmp_var (sort keys %tmp_hash){
					$spets{$subject}{$tmp_var} = $tmp_hash{$tmp_var} unless $tmp_var eq '_';
				}
			}
		}
	}		
}
#print "I got the data!\n";
open STDOUT, ">$ofile" unless not $ofile;
if($with_date){
	print "Subject;Date;SUVR;Centiloid\n";
	foreach my $subject (sort keys %spets) {
		if(exists($spets{$subject}{'experiment'}) and $spets{$subject}{'experiment'}){
			$spets{$subject}{'date'} = xget_exp_data($xconfig{'HOST'}, $jid, $spets{$subject}{'experiment'}, 'date');
			print "$spets{$subject}{'label'};$spets{$subject}{'date'};$spets{$subject}{'surv'};$spets{$subject}{'cl'}\n";
		}
	}
}else{
	print "Subject;SUVR;Centiloid\n";
	foreach my $subject (sort keys %spets) {
		if(exists($spets{$subject}{'experiment'}) and $spets{$subject}{'experiment'}){
			print "$spets{$subject}{'label'};$spets{$subject}{'surv'};$spets{$subject}{'cl'}\n";
		}
	}
}
close STDOUT;
