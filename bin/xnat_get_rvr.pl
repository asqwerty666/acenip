#!/usr/bin/perl
# Get the Visual readings table from XNAT resources
# This is made for MRIFACE project but is intended to be used everywhere
# if lucky!
#
# Copyleft 2022 O. Sotolongo <asqwerty@gmail.com>
#
use strict;
use warnings;
use File::Temp qw(:mktemp tempdir);
use JSON qw(decode_json);
use XNATACE qw(xget_session xget_subjects xget_mri xlist_res xget_res_data);
use Data::Dump qw(dump);
my $xprj;
my $oxfile;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-o/) {$oxfile = shift; chomp($oxfile);}
	if (/^-x/) {$xprj = shift; chomp($xprj);}
}
die "Should supply XNAT project" unless $xprj;
$oxfile = $xprj.'_rvr_data.csv' unless $oxfile;
my %xconf = xget_session();
#get the jsessionid
my $jid = $xconf{'JSESSION'};
#get the subjects list
my %subjects = xget_subjects($xconf{'HOST'}, $jid, $xprj);
my $dhead ="";
my $dbody="";
foreach my $sid (sort keys %subjects){
	#$subjects{$sid}{'experimentID'} = xget_mri($xconf{'HOST'}, $jid, $xprj, $sid);
	my @experiments = xget_mri($xconf{'HOST'}, $jid, $xprj, $sid);
	foreach my $experiment (@experiments){
		my %rvr = xlist_res($xconf{'HOST'}, $jid, $experiment, 'RVR');
		my %rvr_data;
		my $date;
		foreach my $rfile (sort keys %rvr){
			if ($rfile =~ /.*\.json$/){
				%rvr_data = xget_res_data($xconf{'HOST'}, $jid, $experiment,'RVR',$rfile);
			}
		}
		my @akeys;
		my @adata;
		foreach my $rvrk (sort keys %rvr_data){
			unless ($dhead){
				push @akeys, $rvrk unless $rvrk eq 'Subject';
			}
			push @adata, $rvr_data{$rvrk} unless $rvrk eq 'Subject';
		}
		$dhead = 'Subject_ID,'. join ',', @akeys unless $dhead;
		if (exists($rvr_data{'Subject'}) and $rvr_data{'Subject'}){
			$dbody .= $rvr_data{'Subject'}.','. join ',', @adata;
			$dbody .= "\n";
		}
	}
}
open ODF, ">$oxfile";
print ODF "$dhead\n$dbody";
close ODF;
