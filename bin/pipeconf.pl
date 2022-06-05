#!/usr/bin/perl
#
# Read, write or update the configuration file for
# a neuroimaging project, located at $HOME/.config/neuro/.
#
# Copyleft 2022 O. Sotolongo <asqwerty@gmail.com>
#
use strict;
use warnings;
use Data::Dump qw(dump);
my $operation;
my $prj;
my $chain;
my $ddir;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-r/) {$operation = "read";}
	if (/^-p/) {$prj = shift; chomp $prj;}
	if (/^-u/ or /^-a/) {$operation = "add"; $chain = shift; chomp $chain;}
	if (/^-c/) {$operation = "create"; $ddir = shift; chomp $ddir;}
}
die "Should supply operation switch" unless $operation;
die "Should supply project name" unless $prj;
my $cpath = $ENV{'HOME'}.'/.config/neuro/';
my $ifile = $cpath.$prj.'.cfg';
my %pconf;
$ddir = '/home/data/'.$prj unless $ddir;
#dump %pconf; exit;
if ($operation eq "read"){
	open IDF, "<$ifile" or die "No configuration file";
	while(<IDF>){
		my ($key, $value) = /(.*)\s=\s(.*)/;
		print "$key = $value\n";
	}
}elsif ($operation eq "add"){
	open IDF, "<$ifile" or die "No configuration file";
	while(<IDF>){
		my ($key, $value) = /(.*)\s=\s(.*)/;
		$pconf{$key} = $value;
	}
	my ($key, $value) = split '=', $chain;
	$pconf{$key} = $value;
 	open ODF, ">$ifile";
	foreach my $key (sort keys %pconf){
		print ODF "$key = $pconf{$key}\n";
	}
	close ODF;	
}elsif ($operation eq "create"){
	$pconf{'DATA'} = $ddir;
	$pconf{'BIDS'} = $ddir.'/bids';
	$pconf{'SRC'} = $ddir.'/raw';
	$pconf{'WORKING'} = $ddir.'/working';
	$pconf{'XNAME'} = $prj;
	open ODF, ">$ifile";
	foreach my $key (sort keys %pconf){
		print ODF "$key = $pconf{$key}\n";
	}
	close ODF;
}else {
	print "No valid operation\n";
}
