#!/usr/bin/perl
#
# This is intended to test the functions that interact with XNAT
#
use strict;
use warnings;
use XNATACE qw(xget_session xlist_res xget_res_file);
#use SLURMACE qw(wait4jobs);
use Data::Dump qw(dump);

my $xprj = 'mriface';
my $xbj = 'XNAT_S00823';
my $xpx = 'XNAT_E00917';
my $fsfile = 'D22541783.tar.gz';

my %conn = xget_session();
#my  $xdata = xget_dicom($conn{'HOST'}, $conn{'JSESSION'}, $xpx, '/old_nas/mri_face/tmp/', 't1_mprage_sag_p2_iso,t2_space_FLAIR_sag_p2_ns-t2prep');
my %res = xlist_res($conn{'HOST'}, $conn{'JSESSION'}, $xpx, 'FS');
foreach my $fres (sort keys %res){
	if ($fres =~ /\.stats$/){
		print "$fres -> $res{$fres}\n";
	}
}
#my $xdata = xget_res_file($conn{'HOST'}, $conn{'JSESSION'},$xpx,'FS', $fsfile, 'tmp.tar.gz');
#print "$xdata\n";
#my @jobs = ('296335');

#wait4jobs(@jobs);
