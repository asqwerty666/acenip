#!/usr/bin/perl
use strict;
use warnings;
use File::Basename qw(basename);
use Data::Dump qw(dump);
my $ifile = shift;
my $fname = basename $ifile;
my ($xn1, $xn2, $sn) = $fname =~ /(\S+)\s*(\S*),\s*(\S+\s*\S*)\.zip/;

#print "$xn1, $xn2, $sn\n";

#Cargo los datos de conexion a la DB 
my $sqlconf_file = $ENV{'HOME'}.'/.sqlcmd'; 
my %sqlconf; open IDF, "<$sqlconf_file"; 
while (<IDF>){         
	if (/^#.*/ or /^\s*$/) { next; }         
	my ($n, $v) = /(.*)=(.*)/;         
	$sqlconf{$n} = $v; 
}
my $conn;
$sn =~ s/(\s)/\\$1/g;
if($xn2){
	$conn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT xapellido1, xapellido2, xnombre, his_interno FROM [UNIT4_DATA].[imp].[vh_pac_gral] WHERE xapellido1 = \'"'.$xn1.'"\' and xapellido2 = \'"'.$xn2.'"\';" | grep '.$xn1;
}else{
	$conn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT xapellido1, xapellido2, xnombre, his_interno FROM [UNIT4_DATA].[imp].[vh_pac_gral] WHERE xapellido1 = \'"'.$xn1.'"\' and xnombre = \'"'.$sn.'"\';" | grep '.$xn1;
}
#print "$conn\n";
my $tdata = qx/$conn/;
my @rec = split /\n/, $tdata;
#dump @rec;
foreach my $entry (@rec){
	my ($name, $nhc) = $entry =~ /(.*),(\d+)\s*$/;
	if ($nhc) {
		print "$name -->> $nhc\n";
		$conn =  'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT xdtprogramado,xdtvisitado,xestado_id,his_interno FROM [UNIT4_DATA].[imp].[his_cites_programa] WHERE xprestacion_id LIKE \'MRI\' and his_interno = \''.$nhc.'\';" | grep '.$nhc;
		my $rdata = qx/$conn/;
		my @rrec = split /\n/, $rdata;
		foreach my $mri (@rrec){
			print "-->> $mri -->> $nhc\n";
		}
	}
}
