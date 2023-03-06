#!/usr/bin/perl 
use strict; 
use warnings;
my $nhc = shift;
die "Should supply NHC\n" unless $nhc;
my $sqlconf_file = $ENV{'HOME'}.'/.sqlcmd'; 
my %sqlconf; 
open IDF, "<$sqlconf_file"; while (<IDF>){         
	if (/^#.*/ or /^\s*$/) { next; }         
	my ($n, $v) = /(.*)=(.*)/;         
	$sqlconf{$n} = $v; 
}
my $conn;
$conn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT xapellido1, xapellido2, xnombre, his_interno FROM [UNIT4_DATA].[imp].[vh_pac_gral] WHERE his_interno = \'"'.$nhc.'"\';"';
system($conn);
