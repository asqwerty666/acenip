#!/usr/bin/perl
#
# This is for getting age at MRI date
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
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-o/) {$oxfile = shift; chomp($oxfile);}
	if (/^-x/) {$xprj = shift; chomp($xprj);}
}
die "Should supply XNAT project" unless $xprj;
$oxfile = $xprj.'_age_data.csv' unless $oxfile;
my %xconf = xget_session();
my $jid = $xconf{'JSESSION'};
my %subjects = xget_subjects($xconf{'HOST'}, $xconf{'JSESSION'}, $xprj);
foreach my $sbj (sort keys %subjects){
	$subjects{$sbj}{'experiment'} = xget_mri($xconf{'HOST'}, $xconf{'JSESSION'}, $xprj, $sbj);
	my $mri_date = xget_exp_data($xconf{'HOST'}, $xconf{'JSESSION'}, $subjects{$sbj}{'experiment'}, 'date');
	my $dob = xget_sbj_demog($xconf{'HOST'}, $xconf{'JSESSION'}, $sbj, 'dob');
	#print "$sbj -> $mri_date -> $dob\n";
		if ($mri_date and $dob){
			my $ddif = Delta_Format(DateCalc(ParseDate($dob),ParseDate($mri_date)),2,"%hh")/(24*365.2425);
			$subjects{$sbj}{'age'} = nearest(0.1, $ddif);
			print "$subjects{$sbj}{'label'}, $subjects{$sbj}{'age'}\n";
		}
}
open ODF, ">$oxfile";
print ODF "Subject_ID,AGE\n";
foreach my $subject (sort keys %subjects){
	if(exists($subjects{$subject}{'age'})){
		print ODF "$subjects{$subject}{'label'},$subjects{$subject}{'age'}\n";
	}
}
close ODF;
