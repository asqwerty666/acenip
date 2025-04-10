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
my $cfile;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-o/) {$oxfile = shift; chomp($oxfile);}
	if (/^-x/) {$xprj = shift; chomp($xprj);}
	if (/^-c/) {$cfile = shift; chomp($cfile);}
}
die "Should supply XNAT project" unless $xprj;
$oxfile = $xprj.'_rvr_data.csv' unless $oxfile;
#my %xconf = xget_session();
#get the jsessionid
#my $jid = $xconf{'JSESSION'};
# Do you want to process just a subset? Read the supplied list of subjects  
my @plist;
if ($cfile and -f $cfile) {
	open my $handle, "<$cfile";
	chomp (@plist = <$handle>);
	close $handle;
}
#get the subjects list
my %subjects = xget_subjects($xprj);
my $dhead ="";
my $dbody="";
foreach my $sid (sort keys %subjects){
	my $go = 0;
	if ($cfile) {
		if (grep {/$sid/} @plist) {$go = 1;}
	}else{
		 $go = 1;
	}
	if ($go){
		#$subjects{$sid}{'experimentID'} = xget_mri($xconf{'HOST'}, $jid, $xprj, $sid);
		my @experiments = xget_mri($xprj, $sid);
		foreach my $experiment (@experiments){
			my %rvr = xlist_res($experiment, 'RVR');
			my %rvr_data;
			my $date;
			foreach my $rfile (sort keys %rvr){
				if ($rfile =~ /.*\.json$/){
					%rvr_data = xget_res_data($experiment,'RVR',$rfile);
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
}
open ODF, ">$oxfile";
print ODF "$dhead\n$dbody";
close ODF;
