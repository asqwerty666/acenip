#!/usr/bin/perl
# Put the Visual readings into XNAT resources
# This is made for MRIFACE project but is intended to be used everywhere
# if lucky!
#
# Copyleft 2022 O. Sotolongo <asqwerty@gmail.com> 
# 
use strict;
use warnings;
use XNATACE qw(xget_conf xget_session xget_mri xcreate_res xput_res_file);
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
#die "Should supply reports directory" unless $rep_dir;
die "Should supply XNAT project" unless $xprj;
my %xconf = xget_session();
my $tmp_dir = $ENV{TMPDIR};
my %vrdata;
my %rdata;
# get the session ID
my $jid = $xconf{'JSESSION'};

if ($rep_dir) {
	my @pdfs = find(file => 'name' => "*.pdf", in => $rep_dir);
	foreach my $report (@pdfs) {
		my $bnreport = basename $report;
		(my $xsbj = $bnreport) =~ s/.pdf//;
		$vrdata{$xsbj} = xget_mri($xconf{'HOST'}, $jid, $xprj, $xsbj);
		xcreate_res($xconf{'HOST'}, $jid, $vrdata{$xsbj}, 'RVR');
		xput_res_file($xconf{'HOST'}, $jid, $vrdata{$xsbj}, 'RVR', 'report_'.$xsbj.'.pdf', $report);
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
			xput_res_file($xconf{'HOST'}, $jid, $vrdata{${$mrdata}{'Subject'}}, 'RVR', 'report_data.json', $tvrf);
			unlink $tvrf;
		}
	}
} else {
	die "Should supply CSV file!\n" unless $vrfile;
	my $ref_vr = csv(in => $vrfile, headers => "auto");
	foreach my $mrdata (@$ref_vr){
		my $rep_body = '{"ResultSet":{"Result":[{';
		my @rep_arr;
		foreach my $rk (sort keys %$mrdata){
			push @rep_arr, '"'.$rk.'":"'.${$mrdata}{$rk}.'"';
		}
		$rep_body .= join ',', @rep_arr;
		$rep_body .= '}]}}';
		my $tvrf = mktemp($tmp_dir.'/rvr_data.XXXXX');
		open TDF, ">$tvrf";
		print TDF "$rep_body\n";
		close TDF;
		my $esbj = xget_mri($xconf{'HOST'}, $jid, $xprj, ${$mrdata}{'Subject'}); 
		xput_res_file($xconf{'HOST'}, $jid, $esbj, 'RVR', 'report_data.json', $tvrf);
		unlink $tvrf;
	}
}


