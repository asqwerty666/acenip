#!/usr/bin/perl
#
# This is for getting stored results at MRI experiment resource
# Intended for MRIFACE protocol
# All info is XNAT stored.
#
# Copyleft 2022 <asqwerty@gmail.com>
#
use strict;
use warnings;
use XNATACE qw(xget_session xget_subjects xget_mri xget_exp_data xget_sbj_demog);
use JSON;
use Date::Manip;
use Math::Round;

my $xprj;
my $oxfile;
my $xvar;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-o/) {$oxfile = shift; chomp($oxfile);}
	if (/^-x/) {$xprj = shift; chomp($xprj);}
	if (/^-v/) {$xvar = shift; chomp($xvar);}
}
die "Should supply XNAT project" unless $xprj;
$xvar =~ s/,/_/g;
my @avar = split '_',$xvar;
$oxfile = $xprj.'_'.$xvar.'_data.csv' unless $oxfile;
my %xconf = xget_session();
my $jid = $xconf{'JSESSION'};
my %subjects = xget_subjects($xconf{'HOST'}, $xconf{'JSESSION'}, $xprj);
foreach my $sbj (sort keys %subjects){
	$subjects{$sbj}{'experiment'} = xget_mri($xconf{'HOST'}, $xconf{'JSESSION'}, $xprj, $sbj);
	print "$subjects{$sbj}{'label'}";
	foreach my $axvar (@avar){
		if ($axvar eq 'age'){
			my $mri_date = xget_exp_data($xconf{'HOST'}, $xconf{'JSESSION'}, $subjects{$sbj}{'experiment'}, 'date');
			my $dob = xget_sbj_demog($xconf{'HOST'}, $xconf{'JSESSION'}, $sbj, 'dob');
			if ($mri_date and $dob){
				my $ddif = Delta_Format(DateCalc(ParseDate($dob),ParseDate($mri_date)),2,"%hh")/(24*365.2425);
				$subjects{$sbj}{'age'} = nearest(0.1, $ddif);
			}
		}else{
			my $foo_var = xget_sbj_demog($xconf{'HOST'}, $xconf{'JSESSION'}, $sbj, $axvar);
			if ($foo_var){
				$subjects{$sbj}{$axvar} = $foo_var;
			}
		}
		if(exists($subjects{$sbj}{$axvar}) and $subjects{$sbj}{$axvar}){
			print ", $subjects{$sbj}{$axvar}";
		}
	}
	print "\n";
}
(my $nvar = $xvar) =~ s/(\w+)/\u$1/;
open ODF, ">$oxfile";
print ODF "Subject_ID";
foreach my $axvar (@avar){
	(my $nvar = $axvar) =~ s/(\w+)/\u$1/;
	print ODF ",$nvar";
}
print ODF "\n";
foreach my $subject (sort keys %subjects){
	print ODF "$subjects{$subject}{'label'}";
	foreach my $axvar (@avar){
		if(exists($subjects{$subject}{$axvar})){
			print ODF ",$subjects{$subject}{$axvar}";
		}
	}
	print ODF "\n";
}
close ODF;