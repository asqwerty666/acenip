#!/usr/bin/perl
#
# This is intended to test the functions that interact with XNAT
#
use strict;
use warnings;
use XNATACE qw(xget_conf xget_session xget_sbj_data);
use Data::Dump qw(dump);

my %conn = xget_conf();

my $xprj = 'f5cehbi';
my $xpx = 'XNAT5_E00704';
my $sbj = 'XNAT_S00086';

my $jid = xget_session(\%conn);
my $xdata = xget_sbj_data($conn{'HOST'}, $jid, $sbj, 'label');
print "$xdata\n";
