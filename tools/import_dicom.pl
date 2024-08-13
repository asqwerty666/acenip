#!/usr/bin/perl
use strict;
use warnings;
use XNATACE qw(xput_dicom xnew_dicom check_status);
use File::Basename qw(basename);
use File::Temp qw(:mktemp tempdir);
use File::Copy::Recursive qw(dircopy);
use File::Find::Rule;
use Archive::Any;
use Data::Dump qw(dump);
my $ifile = shift;
my $nhc = shift;
my $xprj = 'test';
my $fname = basename $ifile;
my $tmp_dir = $ENV{'TMPDIR'};
#Cargo los datos de conexion a la DB 
my $sqlconf_file = $ENV{'HOME'}.'/.sqlcmd'; 
my %sqlconf; open IDF, "<$sqlconf_file"; 
while (<IDF>){         
	if (/^#.*/ or /^\s*$/) { next; }         
	my ($n, $v) = /(.*)=(.*)/;         
	$sqlconf{$n} = $v; 
}
my $conn;
unless ($nhc){
	my ($xn1, $xn2, $sn) = $fname =~ /(\S+)\s*(\S*),\s*(\S+\s*\S*).*(\.zip|\/)*$/;
	$xn1 =~ s/\\|\s//g;
	$xn2 =~ s/\\|\s//g;
	$sn =~ s/\\|\s//g;
#print "$xn1, $xn2, $sn\n";

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
		my ($nnhc, $name, $mri) = $entry =~ /(\d+)\s*,(\S*,\S*,\S*\s*\S*),(.*)$/;
		if ($nnhc) {
			$nhc = $nnhc;
			print "$name -->> $mri -->> $nhc\n";
		}
	}
}else{
	my $tmpdir = tempdir(TEMPLATE => $tmp_dir.'/dicom.XXXXX', CLEANUP => 1);
	if ( -f $ifile and $ifile =~ /.*\.zip/ ){
		my $archive = Archive::Any->new($ifile);
		$archive->extract($tmpdir);
	}elsif ( -d $ifile ){
		dircopy($ifile, $tmpdir);
	}else{
		die "This is not a valid file or directory\n";
	}
		my $anondir = tempdir(TEMPLATE => $tmp_dir.'/anon.XXXXX', CLEANUP => 1);
	my @dcms = File::Find::Rule->file()->in($tmpdir);
	my $patid = qx/dckey -k "StudyID" "$dcms[0]" 2>&1/;
	$patid =~ s/\s//g;
	my $sdate = qx/dckey -k "StudyDate" "$dcms[0]" 2>&1/;
	$sdate =~ s/\s//g;
	system("dcanon $tmpdir $anondir/$nhc/$sdate nomove $nhc $patid");
	my $result = ( split /\n/, xput_dicom($xprj, $nhc, $anondir))[0];
	print "\n$result\n";
	my $status;
	do {
		$status = ( split /\n/, check_status($result))[0];
		if ($status){
			$status =~ s/\"//g;
			print ".";
			sleep 30;
		} else{
			$status = 0;
		}
	} while ($status eq "RECEIVING");
	print "\n";
	$conn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT xapellido1, xapellido2, xnombre, his_interno FROM [UNIT4_DATA].[imp].[vh_pac_gral] WHERE his_interno = \'"'.$nhc.'"\';"';
	system($conn);
}

