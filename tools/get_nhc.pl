#!/usr/bin/perl
use strict;
use warnings;
use File::Basename qw(basename);
use Data::Dump qw(dump);
my $ifile = shift;
my $fname = basename $ifile;
my ($xn1, $xn2, $sn) = $fname =~ /(\S+)\s*(\S*),\s*(\S+\s*\S*)(\.zip|\/)*$/;

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
	$conn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT dmg.his_interno, dmg.xapellido1, dmg.xapellido2, dmg.xnombre, cts.xdtprogramado, cts.xdtvisitado, cts.xestado_id FROM [UNIT4_DATA].[imp].[vh_pac_gral] as dmg JOIN [UNIT4_DATA].[imp].[his_cites_programa] as cts ON (dmg.his_interno = cts.his_interno) WHERE dmg.xapellido1 = \'"'.$xn1.'"\' and dmg.xapellido2 = \'"'.$xn2.'"\' and  cts.xprestacion_id LIKE \'MRI\';" | grep '.$xn1;
}else{
	$conn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT dmg.his_interno, dmg.xapellido1, dmg.xapellido2, dmg.xnombre, cts.xdtprogramado, cts.xdtvisitado, cts.xestado_id FROM [UNIT4_DATA].[imp].[vh_pac_gral] as dmg JOIN [UNIT4_DATA].[imp].[his_cites_programa] as cts ON (dmg.his_interno = cts.his_interno) WHERE dmg.xapellido1 = \'"'.$xn1.'"\' and dmg.xnombre = \'"'.$sn.'"\' and  cts.xprestacion_id LIKE \'MRI\';" | grep '.$xn1;
}
#print "$conn\n";
my $tdata = qx/$conn/;
my @rec = split /\n/, $tdata;
#dump @rec;
foreach my $entry (@rec){
	my ($nhc, $name, $mri) = $entry =~ /(\d+)\s*,(\S*,\S*,\S*\s*\S*),(.*)$/;
	if ($nhc) {
		print "$name -->> $mri -->> $nhc\n";
	}
}
