#!/usr/bin/perl
#
# This is intended to test the functions that interact with XNAT
#
use strict;
use warnings;
use XNATACE qw(xget_session xget_res_file);
#use SLURMACE qw(wait4jobs);
use Data::Dump qw(dump);

my $xprj = 'mriface';
my $xbj = 'XNAT_S00823';
my $xpx = 'XNAT_E00917';

my %conn = xget_session();
my  $xdata = xget_res_file($conn{'HOST'}, $conn{'JSESSION'}, $xpx, 'FS', 'lh.BA_exvivo.stats', 'lh.BA_exvivo.stats');
print "$xdata\n";
#my @jobs = ('296335');

#wait4jobs(@jobs);
