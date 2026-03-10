#!/usr/bin/perl
#
# Copyleft 2025 O. Sotolongo <asqwerty@gmail.com>
#
# El objetivo del script es subir los DICOM del proyecto MRIFACE a XNAT
#
# Se reutilizan las bibliotecas Perl de interaccion con XNAT del pipeline ACENIP
# (https://github.com/asqwerty666/acenip/blob/main/lib/XNATACE.pm)
# Aqui se han reescrito y añadido algunas funciones para añadir capacidades interactivas 
# debido a este y otros proyectos
#
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
# DICOM tags por defecto
my $t1tag = 'tfl3d1';
my $t2tag = 'spcir_220';
my $clobber = 0;
# El input obligatorio para añadir a XNAT es la localizacion (source) del DICOM
# y el NHC. En caso de no tener el NHC, el script es capaz de investigar la DB 
# y obtenerlo pero no hace mas nada. Para subir correctamente el DICOM se debe ejecutar de nuevo, 
# añadiendo el NHC suministrado.
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-x/) {$xprj = shift; chomp($xprj);}
	if (/^-s/) {$ifile = shift; chomp($ifile);} # src dir or zip file
	if (/^-i/) {$nhc = shift; chomp($nhc);} #NHC
	# Es posible cambiar los tags por efecto para que se ejecuten correctmente los pipelines
	if (/^-t1/) {$t1tag = shift; chomp($t1tag);}
	if (/^-t2/) {$t2tag = shift; chomp($t2tag);}
	# si existe ya un DICOM en el sujeto XNAT no se va a ñadir nada
	# Se ha de utilizar la opcion -c para sobreescribir o añadir otro experimento
	if (/^-c/) {$clobber = 1;}
}
my $params = 'dcmT1tag='.$t1tag.'&dcmT2tag='.$t2tag;
my $fname = basename $ifile;
my $tmp_dir = $ENV{'TMPDIR'};
# Cargo los datos de conexion a la DB 
my $sqlconf_file = $ENV{'HOME'}.'/.sqlcmd'; 
my %sqlconf; open IDF, "<$sqlconf_file"; 
while (<IDF>){         
	if (/^#.*/ or /^\s*$/) { next; }         
	my ($n, $v) = /(.*)=(.*)/;         
	$sqlconf{$n} = $v; 
}
my $conn;
unless ($nhc){
	# Si no se ha dado el NHC, se ha de mirar en la DB intentando adivinar los apellidos
	# y el nombre a partir del path del archivo o directorio
	# Puede que el procedimiento no funcione, en ese caso hay un script aparte (query.sh)
	# par ainteraccionar con la DB donde se puede mirar por un solo apellido
	my ($xn1, $xn2, $sn) = $fname =~ /(\S+)\s*(\S*),\s*(\S+\s*\S*).*(\.zip|\/)*$/;
	$xn1 =~ s/\\|\s//g;
	#La DB solo entiende mayusculas pero el directorio no tiene porque estar escrito asi
	$xn1 =~ tr/[a-z]/[A-Z]/; 
	$xn2 =~ s/\\|\s//g;
	$xn2 =~ tr/[a-z]/[A-Z]/;
	$sn =~ s/\\|\s//g;
	$sn =~ s/(\s)/\\$1/g;
	$sn =~ tr/[a-z]/[A-Z]/;
	if($xn2){
		# Si el path del sujeto tiene un segundo apellido se hace un query usando los dos apellidos
		$conn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT dmg.his_interno, dmg.xapellido1, dmg.xapellido2, dmg.xnombre, cts.xdtprogramado, cts.xdtvisitado, cts.xestado_id FROM [UNIT4_DATA].[imp].[vh_pac_gral] as dmg JOIN [UNIT4_DATA].[imp].[his_cites_programa] as cts ON (dmg.his_interno = cts.his_interno) WHERE dmg.xapellido1 = \'"'.$xn1.'"\' and dmg.xapellido2 = \'"'.$xn2.'"\' and  cts.xprestacion_id LIKE \'MRI\';" | grep '.$xn1;
	}else{
		# si no hay segundo apellido se hace un query con el primer apellido y el nombre
		$conn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT dmg.his_interno, dmg.xapellido1, dmg.xapellido2, dmg.xnombre, cts.xdtprogramado, cts.xdtvisitado, cts.xestado_id FROM [UNIT4_DATA].[imp].[vh_pac_gral] as dmg JOIN [UNIT4_DATA].[imp].[his_cites_programa] as cts ON (dmg.his_interno = cts.his_interno) WHERE dmg.xapellido1 = \'"'.$xn1.'"\' and dmg.xnombre = \'"'.$sn.'"\' and  cts.xprestacion_id LIKE \'MRI\';" | grep '.$xn1;
	}
	my $tdata = qx/$conn/;
	my @rec = split /\n/, $tdata;
	foreach my $entry (@rec){
		# Si la consulta ha sido satisfactoria se saca por STDOUT el resultado
		my ($nnhc, $name, $mri) = $entry =~ /(\d+)\s*,(\S*,\S*,\S*\s*\S*),(.*)$/;
		if ($nnhc) {
			$nhc = $nnhc;
			print "$name -->> $mri -->> $nhc\n";
		}
	}
}else{
	# Si se suministra el NHC vamos a intentar crear el sujeto y subir el DICOM
	unless ($clobber) {
		# A no ser que se haya forzado (-c) miramos si existe ya el sujeto en la DB
		# En ese caso se avisa por STDOUT y no se hace nada
		my $sbj_id = xget_sbj_id($xprj, $nhc);
		if ($sbj_id) {
			print "It seems that subject already exists. If you want to override or add a different experiment run again with -c switch\n";
			exit;
		}
	}
	my $tmpdir = tempdir(TEMPLATE => $tmp_dir.'/dicom.XXXXX', CLEANUP => 1);
	# Si las imagenes estan en un zip, este se descomprime a un directorio temporal
	# Si estan en un directorio, se copian a un directorio temporal
	if ( -f $ifile and $ifile =~ /.*\.zip$/ ){
		my $archive = Archive::Any->new($ifile);
		$archive->extract($tmpdir);
	}elsif ( -d $ifile ){
		dircopy($ifile, $tmpdir);
	}else{
		die "This is not a valid file or directory\n";
	}
	# El primer paso es anonimizar las imagenes con dcm3tools
	# (https://www.dclunie.com/dicom3tools.html)
	my $anondir = tempdir(TEMPLATE => $tmp_dir.'/anon.XXXXX', CLEANUP => 1);
	my @dcms = File::Find::Rule->file()->in($tmpdir);
	my $patid = qx/dckey -k "StudyID" "$dcms[0]" 2>&1/;
	$patid =~ s/\s//g;
	my $sdate = qx/dckey -k "StudyDate" "$dcms[0]" 2>&1/;
	$sdate =~ s/\s//g;
	system("dcanon $tmpdir $anondir/$nhc/$sdate nomove $nhc $patid");
	# Una vez anoonimizado se intenta subir el DICOM
	my $result = ( split /\n/, xput_dicom($xprj, $nhc, $anondir))[0];
	# En caso de que el resultado de la subida sea incorrecto se avisa y se sale del programa
	# Si se ha lelgado hasta aqui correctmante, esto suele ser por problemas de XNAT. Asi que 
	# hay que mirar que pasa en la VM
	die "Can not upload DICOM to XNAT\n" unless $result;
	# Si el archivo se ha subido OK la funcion xput_dicom() devuelve la localizacion
	# del DICOM en el xapi de XNAT. Podriamos esperar a que XNAT la parsee y haga el procedimiento 
	# de archiving pero lo que voy a hacer es forzarlo par apoder ejecutar los pipelines directamente
	# y cambiar los datos del sujeto en el sistema
	my $status = force_archive($result);
	# Como comprobacion de que lo hemos echon todo correcto voy a conectar a la DB y escribir en STDOUT 
	# los datos del sujeto para el NHC que hemos subido. Ojo que esto hay que hacerlo y comprobarlo porque 
	# el sistema de DB de ACE y Corachan son distintos y aqui intervienen dos personas escribiendo datos 
	# MANUALMENTE. Si vemos que no coincide con lo que queriamos hay que borrar el sujeto y ver que ha pasado
	$conn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT xapellido1, xapellido2, xnombre, his_interno FROM [UNIT4_DATA].[imp].[vh_pac_gral] WHERE his_interno = \'"'.$nhc.'"\';"';
	system($conn);
	# Para facilitar consultas futuras de XNAT voy a extraer sexo y fecha de nacimiento de la DB
	my $sconn = 'sqlcmd -U '.$sqlconf{'USER'}.' -P '.$sqlconf{'PASSWORD'}.' -S '.$sqlconf{'HOST'}.' -s "," -W -Q "SELECT his_interno, xfecha_nac, xsexo_id FROM [UNIT4_DATA].[imp].[vh_pac_gral] WHERE his_interno = \'"'.$nhc.'"\';" | grep '.$nhc;
	my $rdata = qx/$sconn/;
	my %subject;
	$subject{'label'} = $nhc;
	# Ahora voy a mirar si el sujeto esta OK en XNAT y actualizo estos datos
	# En caso de que no haya entrado todavia el sujeto de xapi a archive 
	# tengo que esperar a que este hecho
	while (not $subject{'ID'}) {
		$subject{'ID'} = xget_sbj_id($xprj, $nhc);
		# He puesto dos segundos porque si XNAT esta OK esto debneria ser rapido
		sleep 2;
	}
	# Ya que el sujeto esta OK voy a ejecutar los pipelines
	# La forma mas sencilla es ejecutarlos en todos los MRI del 
	# sujeto. Si hemos añadido uno nuevo esto puede implicar una
	# tarea extra del cluster pero como es raro voy aignorarlo
	# ya que se supone que el proyecto no tiene datos longitudinales
	# OJO que cuando esto se convierta en un proyectom logitudinal,
	# que no esta descartado del todo, se ha de mirar como averiguar 
	# si queremos hacerlo asi
	my @pipes = xget_mri_pipelines($xprj);
	dump @pipes;
	my @mris = xget_mri($xprj, $subject{'ID'});
	foreach my $mri (@mris){
		foreach my $pipe (@pipes){
			# Para no pisar la ejecucion de los pipelines los lanzo cada uno 
			# cada 30 segundos. Vamos que de momento son dos pipes, asi que tampoca es mucho
			# pero XNAT se hace un lio si se ejcuta todo el mismo tiempo
			sleep 30;
			xrun_mri_pipeline($xprj, $pipe, $mri, $params);
			print "$pipe launched  on $mri\n";
		}
	}
	# Ahora voy a cambiar sexo y DOB en XNAT con los datos que he extradio de la DB
	my ($xdob, $xgender) = $rdata =~ /$nhc\s*,\s*(\d{4}-\d{2}-\d{2}).*,(\d)$/;
	if($xdob and $xgender){
		$subject{'dob'} = $xdob;
		$subject{'gender'} = $xgender==1?'male':'female';
	}
	if (exists($subject{'dob'}) and exists($subject{'gender'})){
		xput_sbj_data($subject{'ID'}, 'gender,dob', $subject{'gender'}.','.$subject{'dob'});
	}
}
