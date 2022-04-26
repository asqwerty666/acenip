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
my $xconf_file = $ENV{'HOME'}.'/.xnatapic/xnat.conf';
my %xconf;
open IDF, "<$xconf_file";
while (<IDF>){
	if (/^#.*/ or /^\s*$/) { next; }
	my ($n, $v) = /(.*)=(.*)/;
	$xconf{$n} = $v;
}
#get the jsessionid
my $q = 'curl -f -X POST -u "'.$xconf{'USER'}.':'.$xconf{'PASSWORD'}.'" "'.$xconf{'HOST'}.'/data/JSESSION" 2>/dev/null';
my $jid = qx/$q/;
#get the subjects list
my %subjects;
$q = 'curl -f -b JSESSIONID='.$jid.' -X GET "'.$xconf{'HOST'}.'/data/projects/'.$xprj.'/subjects?format=csv&columns=ID,label" 2>/dev/null';
my @sbj_res = split '\n', qx/$q/;
my $dhead ="";
my $dbody="";
foreach my $sbj_prop (@sbj_res){
	if ($sbj_prop =~ /^XNAT/){
		my ($sid,$slabel) = $sbj_prop =~ /^(XNAT.+),(\S+),(.*)$/;
		$subjects{$sid}{'label'} = $slabel;
		my $qe = 'curl -f -b JSESSIONID='.$jid.' -X GET "'.$xconf{'HOST'}.'/data/projects/'.$xprj.'/subjects/'.$sid.'/experiments?format=json&xsiType=xnat:mrSessionData" 2>/dev/null';
		my $json_res = qx/$qe/;
		#print $json_res;
		my $exp_prop = decode_json $json_res;
		foreach my $experiment (@{$exp_prop->{'ResultSet'}{'Result'}}){
				$subjects{$sid}{'experimentID'} = $experiment->{'ID'};
		}
		if (exists($subjects{$sid}{'experimentID'}) and $subjects{$sid}{'experimentID'}){
			my $qr = 'curl -f -b JSESSIONID='.$jid.' -X GET "'.$xconf{'HOST'}.'/data/projects/'.$xprj.'/experiments/'.$subjects{$sid}{'experimentID'}.'/resources/RVR/files?format=json" 2>/dev/null';
			$json_res = qx/$qr/;
			#print "$json_res\n";
			my $rvr_prop = decode_json $json_res;
			my $report_uri;
			foreach my $rvr_res (@{$rvr_prop->{'ResultSet'}{'Result'}}){
				if ($rvr_res->{'Name'} eq 'report_data.json'){
					$report_uri = $rvr_res->{'URI'};
				}
			}
			if ($report_uri){
				$qr = 'curl -f -b JSESSIONID='.$jid.' -X GET "'.$xconf{'HOST'}.$report_uri.'" 2>/dev/null';
				$json_res = qx/$qr/;
				#print "$json_res\n";
				my $report_data = decode_json $json_res;
				foreach my $var_data (@{$report_data->{'ResultSet'}{'Result'}}){
					my @akeys;
					my @adata;
					foreach my $kdata (sort keys %{$var_data}){
						unless ($dhead){
							push @akeys, $kdata unless $kdata eq 'Subject';
						}
						push @adata, ${$var_data}{$kdata} unless $kdata eq 'Subject';
					}
					$dhead = 'Subject_ID,'. join ',', @akeys unless $dhead;
					$dbody .= ${$var_data}{'Subject'}.','. join ',', @adata;
					$dbody .= "\n";
				}
			}
		}
	}
}
open ODF, ">$oxfile";
print ODF "$dhead\n$dbody";
close ODF;
