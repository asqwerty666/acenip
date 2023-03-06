#!/usr/bin/perl
#
# Copyleft 2022 O. Sotolongo <asqwerty@gmail.com>
#
use strict;
use warnings;
use XNATACE qw(xget_session xget_sbj_id xput_sbj_data);
use File::Temp qw(:mktemp tempdir);
use Data::Dump qw(dump);
# Get input
my $xprj = 'unidad';
my $sbj;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-x/) {$xprj = shift; chomp($xprj);}
	if (/^-i/) {$sbj = shift; chomp($sbj);}
}
die "Should supply XNAT project\n" unless $xprj;
die "Should supply subject label\n" unless $sbj;
#get connection to XNAT
my %conn = xget_session();
my %subject;
$subject{'label'} = $sbj;
$subject{'ID'} = xget_sbj_id($conn{'HOST'}, $conn{'JSESSION'}, $xprj, $sbj);
die "No such subject in this project\n" unless $subject{'ID'}; 
my $sqlconf_file = $ENV{'HOME'}.'/.sqlcmd';
my %sqlconf;
open IDF, "<$sqlconf_file";
while (<IDF>){
	if (/^#.*/ or /^\s*$/) { next; }
	my ($n, $v) = /(.*)=(.*)/;
	$sqlconf{$n} = $v;
}
close IDF;

#dump %subjects;
my $sconn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT his_interno, xfecha_nac, xsexo_id FROM [UNIT4_DATA].[imp].[vh_pac_gral] WHERE his_interno = \'"'.$sbj.'"\';" | grep '.$sbj;
my $rdata = qx/$sconn/;
my ($xdob, $xgender) = $rdata =~ /$sbj\s*,\s*(\d{4}-\d{2}-\d{2}).*,(\d)$/;
if($xdob and $xgender){
	$subject{'dob'} = $xdob;
	$subject{'gender'} = $xgender==1?'male':'female';
} 
if (exists($subject{'dob'}) and exists($subject{'gender'})){
	xput_sbj_data($conn{'HOST'}, $conn{'JSESSION'}, $subject{'ID'}, 'gender,dob', $subject{'gender'}.','.$subject{'dob'});
}
dump %subject;
