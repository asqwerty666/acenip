#!/usr/bin/perl
# Put the Visual readings into XNAT resources
# This is made for MRIFACE project but is intended to be used everywhere
# if lucky!
#
# Copyleft 2022 O. Sotolongo <asqwerty@gmail.com> 
# 
use strict;
use warnings;
use XNATACE qw(xconf xget_session xget_mri xput_report xput_rvr);
use File::Find::Rule;
use File::Basename qw(basename);
use Text::CSV qw(csv);
use File::Temp qw( :mktemp tempdir);
use Data::Dump qw(dump);
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
my $xconf_file = $ENV{'HOME'}.'/.xnatapic/xnat.conf';
my %xconf = xconf($xconf_file);
my $tmp_dir = $ENV{TMPDIR};
my %vrdata;
my %rdata;
# get the session ID
my $jid = xget_session(\%xconf);

my @pdfs = find(file => 'name' => "*.pdf", in => $rep_dir);
foreach my $report (@pdfs) {
	my $bnreport = basename $report;
	(my $xsbj = $bnreport) =~ s/.pdf//;
	$vrdata{$xsbj} = xget_mri($xconf{'HOST'}, $jid, $xprj, $xsbj);
	xput_report($xconf{'HOST'}, $jid, $xsbj, $vrdata{$xsbj}, $report);
}
if ($vrfile) {
	my $ref_vr = csv(in => $vrfile, headers => "auto");
	foreach my $mrdata (@$ref_vr){
		my $rep_body = '{"ResultSet":{"Result":[{';
		my @rep_arr;
		foreach my $rk (sort keys %$mrdata){
			#if ($rk ne 'Subject' and $rk ne 'Date'){
			push @rep_arr, '"'.$rk.'":"'.${$mrdata}{$rk}.'"';
			#}
		}
		$rep_body .= join ',', @rep_arr;
		$rep_body .= '}]}}';
		my $tvrf = mktemp($tmp_dir.'/rvr_data.XXXXX');
		open TDF, ">$tvrf";
		print TDF "$rep_body\n";
		close TDF;
		xput_rvr($xconf{'HOST'}, $jid, $vrdata{${$mrdata}{'Subject'}}, $tvrf);
		unlink $tvrf;
	}
}


