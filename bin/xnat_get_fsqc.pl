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
use XNATACE qw(xget_session xget_subjects xget_mri xget_fs_qc);
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
$oxfile = $xprj.'_fsqc_data.csv' unless $oxfile;
my %xconf = xget_session();
#get the jsessionid
my $jid = $xconf{'JSESSION'};
#get the subjects list
my %subjects = xget_subjects($xconf{'HOST'}, $jid, $xprj);
my $dhead ="Subject,FSQC,Notes";
my $dbody="";
my %inbreed;
foreach my $sbj (sort keys %subjects) { $inbreed{$subjects{$sbj}{'label'}} = $sbj; }
foreach my $sid (sort keys %subjects){
	$subjects{$sid}{'experimentID'} = xget_mri($xconf{'HOST'}, $jid, $xprj, $sid);
	if (exists($subjects{$sid}{'experimentID'}) and $subjects{$sid}{'experimentID'}){
		my %tmp_hash = xget_fs_qc($xconf{'HOST'}, $jid, $subjects{$sid}{'experimentID'});
		if(exists($tmp_hash{'rating'}) and $tmp_hash{'rating'}){
			$tmp_hash{'rating'} =~ tr/ODILgR/odilGr/;
			$subjects{$sid}{'FSQC'} = $tmp_hash{'rating'};
			$subjects{$sid}{'Notes'} = $tmp_hash{'notes'};
		}else{
			print "$subjects{$sid}{'label'} -> $subjects{$sid}{'experimentID'} --no rated yet--\n";
			$subjects{$sid}{'FSQC'} = '0';
			$subjects{$sid}{'Notes'} = '0';
		}
	}
#	$dbody .= "$sid,$subjects{$sid}{'FSQC'},$subjects{$sid}{'Notes'}\n";
}
open ODF, ">$oxfile";
print ODF "$dhead\n";
foreach my $sbj (sort keys %inbreed){
	if (exists($subjects{$inbreed{$sbj}})){
		print ODF "$sbj,$subjects{$inbreed{$sbj}}{'FSQC'},$subjects{$inbreed{$sbj}}{'Notes'}\n"
	}
}
close ODF;