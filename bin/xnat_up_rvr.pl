#!/usr/bin/perl
# Put the Visual readings into XNAT resources
# This is made for MRIFACE project but is intended to be used everywhere
# if lucky!
#
# Copyleft 2022 O. Sotolongo <asqwerty@gmail.com> 
# 
use strict;
use warnings;
use File::Find::Rule;
use File::Basename qw(basename);
use Text::CSV qw(csv);
use File::Temp qw( :mktemp tempdir);
use Data::Dump qw(dump);
use XNATACE qw(xget_session xget_mri xget_exp_data xcreate_res xput_res_file);
my $vrfile;
my $rep_dir;
my $xprj;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-i/) {$vrfile = shift; chomp($vrfile);}
    if (/^-d/) {$rep_dir = shift; chomp($rep_dir);}
    if (/^-x/) {$xprj = shift; chomp($xprj);}
}
die "Should supply reports directory" unless $rep_dir;
die "Should supply XNAT project" unless $xprj;
my $tmp_dir = $ENV{TMPDIR};
my %vrdata;
my %rdata;
my %matchexps;
# get the session ID
my %xconf = xget_session();
if ($vrfile) {
	my $ref_vr = csv(in => $vrfile, headers => "auto");
	my $subject;
	foreach my $mrdata (@$ref_vr){
		my $rep_body = '{"ResultSet":{"Result":[{';
		my @rep_arr;
		my $edate;
		foreach my $rk (sort keys %$mrdata){
			push @rep_arr, '"'.$rk.'":"'.${$mrdata}{$rk}.'"';
			$subject = ${$mrdata}{$rk} if $rk eq 'Subject';
			$edate = ${$mrdata}{$rk} if $rk eq 'Date';
		}
		my @experiments = xget_mri($xconf{'HOST'}, $xconf{'JSESSION'}, $xprj, $subject);
		foreach my $experiment (@experiments){
			my $xdate = xget_exp_data($xconf{'HOST'}, $xconf{'JSESSION'}, $experiment, 'date');
			if ($xdate eq $edate) {
				$matchexps{$subject} = $experiment;
				last;
			}
		}
		$rep_body .= join ',', @rep_arr;
		$rep_body .= '}]}}';
		my $tvrf = mktemp($tmp_dir.'/rvr_data.XXXXX');
		open TDF, ">$tvrf";
		print TDF "$rep_body\n";
		close TDF;
		if (exists($matchexps{$subject}) and $matchexps{$subject}){
			### Just in case ###
			xcreate_res($xconf{'HOST'}, $xconf{'JSESSION'}, $matchexps{$subject}, 'RVR');
			####################
			xput_res_file($xconf{'HOST'}, $xconf{'JSESSION'}, $matchexps{$subject}, 'RVR', 'report_data.json', $tvrf);
			my $report = $rep_dir.'/'.$subject.'.pdf' if $rep_dir;
			if (-e $report){
				xput_res_file($xconf{'HOST'}, $xconf{'JSESSION'}, $matchexps{$subject}, 'RVR', 'report_'.$subject.'.pdf', $report);
			}
		}else{
			print "No data for $subject\n";
		}
		unlink $tvrf;
	}
}
