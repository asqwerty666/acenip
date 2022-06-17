#!/usr/bin/perl
#
# This is intended to test the functions that interact with XNAT
#
use strict;
use warnings;
use XNATACE qw(xget_conf xget_session xget_fs_stats);
use Data::Dump qw(dump);

my $xprj = 'f5cehbi';
my $xpx = 'XNAT_E00105';
my $sbj = 'XNAT_S00086';

my %conn = xget_session();
my $xdata = xget_fs_stats($conn{'HOST'}, $conn{'JSESSION'}, $xpx, 'aseg.stats', '/nas/osotolongo/tmp/kakakaka.txt');
print "$xdata\n";
