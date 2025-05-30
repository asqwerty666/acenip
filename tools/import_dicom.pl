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
my $clobber = 0;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-x/) {$xprj = shift; chomp($xprj);}
	if (/^-s/) {$ifile = shift; chomp($ifile);} #src dir or file
	if (/^-i/) {$nhc = shift; chomp($nhc);}
	if (/^-t1/) {$t1tag = shift; chomp($t1tag);}
	if (/^-t2/) {$t2tag = shift; chomp($t2tag);}
	if (/^-c/) {$clobber = 1;}
}
my $params = 'dcmT1tag='.$t1tag.'&dcmT2tag='.$t2tag;
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
	$sn =~ s/(\s)/\\$1/g;
	if($xn2){
		$conn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT dmg.his_interno, dmg.xapellido1, dmg.xapellido2, dmg.xnombre, cts.xdtprogramado, cts.xdtvisitado, cts.xestado_id FROM [UNIT4_DATA].[imp].[vh_pac_gral] as dmg JOIN [UNIT4_DATA].[imp].[his_cites_programa] as cts ON (dmg.his_interno = cts.his_interno) WHERE dmg.xapellido1 = \'"'.$xn1.'"\' and dmg.xapellido2 = \'"'.$xn2.'"\' and  cts.xprestacion_id LIKE \'MRI\';" | grep '.$xn1;
	}else{
		$conn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT dmg.his_interno, dmg.xapellido1, dmg.xapellido2, dmg.xnombre, cts.xdtprogramado, cts.xdtvisitado, cts.xestado_id FROM [UNIT4_DATA].[imp].[vh_pac_gral] as dmg JOIN [UNIT4_DATA].[imp].[his_cites_programa] as cts ON (dmg.his_interno = cts.his_interno) WHERE dmg.xapellido1 = \'"'.$xn1.'"\' and dmg.xnombre = \'"'.$sn.'"\' and  cts.xprestacion_id LIKE \'MRI\';" | grep '.$xn1;
	}
	my $tdata = qx/$conn/;
	my @rec = split /\n/, $tdata;
	foreach my $entry (@rec){
		my ($nnhc, $name, $mri) = $entry =~ /(\d+)\s*,(\S*,\S*,\S*\s*\S*),(.*)$/;
		if ($nnhc) {
			$nhc = $nnhc;
			print "$name -->> $mri -->> $nhc\n";
		}
	}
}else{
	unless ($clobber) {
		my $sbj_id = xget_sbj_id($xprj, $nhc);
		if ($sbj_id) {
			print "It seems that subject already exists. If you want to override or add a different experiment run again with -c switch\n";
			exit;
		}
	}
	my $tmpdir = tempdir(TEMPLATE => $tmp_dir.'/dicom.XXXXX', CLEANUP => 1);
	#$ifile = escape_name($ifile);
	if ( -f $ifile and $ifile =~ /.*\.zip$/ ){
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
	die "Can not upload DICOM to XNAT\n" unless $result;
	my $status = force_archive($result);
	$conn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT xapellido1, xapellido2, xnombre, his_interno FROM [UNIT4_DATA].[imp].[vh_pac_gral] WHERE his_interno = \'"'.$nhc.'"\';"';
	system($conn);
	my $sconn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT his_interno, xfecha_nac, xsexo_id FROM [UNIT4_DATA].[imp].[vh_pac_gral] WHERE his_interno = \'"'.$nhc.'"\';" | grep '.$nhc;
	my $rdata = qx/$sconn/;
	my %subject;
	$subject{'label'} = $nhc;
	while (not $subject{'ID'}) {
		$subject{'ID'} = xget_sbj_id($xprj, $nhc);
		sleep 10;
	}
	my @pipes = xget_mri_pipelines($xprj);
	my @mris = xget_mri($xprj, $subject{'ID'});
	foreach my $mri (@mris){
		foreach my $pipe (@pipes){
			sleep 60;
			xrun_mri_pipeline($xprj, $pipe, $mri, $params);
		}
	}
	my ($xdob, $xgender) = $rdata =~ /$nhc\s*,\s*(\d{4}-\d{2}-\d{2}).*,(\d)$/;
	if($xdob and $xgender){
		$subject{'dob'} = $xdob;
		$subject{'gender'} = $xgender==1?'male':'female';
	}
	if (exists($subject{'dob'}) and exists($subject{'gender'})){
		xput_sbj_data($subject{'ID'}, 'gender,dob', $subject{'gender'}.','.$subject{'dob'});
	}
}
