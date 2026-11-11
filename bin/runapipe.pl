#!/usr/bin/perl
use strict;
use warnings;
use XNATACE qw(xput_dicom xnew_dicom check_status force_archive xget_sbj_id xput_sbj_data xget_mri xget_mri_pipelines xrun_mri_pipeline);
use NEURO4 qw(escape_name);
use File::Basename qw(basename);
use File::Temp qw(:mktemp tempdir);
use File::Copy::Recursive qw(dircopy);
use File::Copy;
use File::Find::Rule;
use Archive::Any;
use Data::Dump qw(dump);
my $ifile; my $nhc; 
my $xprj = 'unidad';
my $t1tag = 'tfl3d1';
my $t2tag = 'spcir_220';
my $pipe = 'RunFreesurfer';
my $xpx;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-x/) {$xprj = shift; chomp($xprj);}
	if (/^-e/) {$xpx = shift; chomp($xpx);} 
	if (/^-i/) {$nhc = shift; chomp($nhc);}
	if (/^-p/) {$pipe = shift; chomp($pipe);}
	if (/^-t1/) {$t1tag = shift; chomp($t1tag);}
	if (/^-t2/) {$t2tag = shift; chomp($t2tag);}
}
my $params = 'dcmT1tag='.$t1tag.'&dcmT2tag='.$t2tag;
my $tmp_dir = $ENV{'TMPDIR'};
my @mris;
unless ($xpx){
	my %subject;
	$subject{'label'} = $nhc;
	$subject{'ID'} = xget_sbj_id($xprj, $nhc);
	@mris = xget_mri($xprj, $subject{'ID'});
}else{
	push @mris, $xpx;
}
foreach my $mri (@mris){
	xrun_mri_pipeline($xprj, $pipe, $mri, $params);
	print "$mri - $pipe\n";
}
