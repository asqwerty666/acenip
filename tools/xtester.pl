#!/usr/bin/perl
#
# This is intended to test the functions that interact with XNAT
#
use strict;
use warnings;
use XNATACE qw(xget_conf xget_session xget_fs_qc);
use SLURMACE qw(wait4jobs);
use Data::Dump qw(dump);

my $xprj = 'mriface';
my $xpx = 'XNAT_E00565';

#my %conn = xget_session();
#my %xdata = xget_fs_qc($conn{'HOST'}, $conn{'JSESSION'}, $xpx);
#dump %xdata;
#print "$xdata\n";
my @jobs = ('296335');

wait4jobs(@jobs);
