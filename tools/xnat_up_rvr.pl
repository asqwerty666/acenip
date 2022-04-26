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
my %xconf;
open IDF, "<$xconf_file";
while (<IDF>){
	if (/^#.*/ or /^\s*$/) { next; }
	my ($n, $v) = /(.*)=(.*)/;
	$xconf{$n} = $v;
}
#dump %xconf;
close IDF;
my $tmp_dir = $ENV{TMPDIR};
my %vrdata;
my %rdata;
# get the session ID
my $q = 'curl -f -X POST -u "'.$xconf{'USER'}.':'.$xconf{'PASSWORD'}.'" "'.$xconf{'HOST'}.'/data/JSESSION"';
my $jid = qx/$q/;

my @pdfs = find(file => 'name' => "*.pdf", in => $rep_dir);
foreach my $report (@pdfs) {
	my $bnreport = basename $report;
	(my $xsbj = $bnreport) =~ s/.pdf//;
	my $xorder = 'xnatapic list_experiments --project_id '.$xprj.' --subject_id '.$xsbj.' --modality MRI';
	my ($xdata) = qx/$xorder/;
        chomp $xdata;
 	$xdata =~ s/"//g;
	$vrdata{$xsbj} = $xdata;
	my $xcurl = 'curl -f -X PUT -b JSESSIONID='.$jid.' "'.$xconf{'HOST'}.'/data/experiments/'.$xdata.'/resources/RVR" 2>/dev/null';
	system($xcurl);
	$xcurl = 'curl -f -X PUT -b JSESSIONID='.$jid.' "'.$xconf{'HOST'}.'/data/experiments/'.$xdata.'/resources/RVR/files/report_'.$xsbj.'.pdf?overwrite=true" -F file="@'.$report.'"';
	print "$xcurl\n";	
	system($xcurl);
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
		my $xcurl = 'curl -f -X PUT -b JSESSIONID='.$jid.' "'.$xconf{'HOST'}.'/data/experiments/'.$vrdata{${$mrdata}{'Subject'}}.'/resources/RVR/files/report_data.json?overwrite=true" -F file="@'.$tvrf.'"';
		print "$xcurl\n";
		system($xcurl);
		unlink $tvrf;
	}
}


