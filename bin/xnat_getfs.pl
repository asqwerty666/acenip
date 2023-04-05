#!/usr/bin/perl
# Copyright 2021 O. Sotolongo <asqwerty@gmail.com>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details

# Este script captura los resultados de Freesurfer obtenidos en XNAT 
# y los copia localmente en una ruta nativa de Freesurfer.
# Esto es util para realizar procedimientos posteriores 
# como los analisis FSGA o longitudinales, o simplemente un QC

use strict;
use warnings;
use NEURO4 qw(load_project print_help populate check_or_make);
use XNATACE qw(xget_session xget_subjects xget_mri xlist_res xget_res_file);
use SLURMACE qw(send2slurm);
use File::Temp qw(tempdir);
use Data::Dump qw(dump);
my $prj;
my $xprj;
my $tmpdir;
my $cfile="";
my $overwrite = 0;
my $tmp_path = $ENV{'TMPDIR'};
my $debug = $ENV{'PWD'}.'/subjects.list';
$tmpdir = $tmp_path; # Esto para poder compartir en el cluster el directorio temporal
#$tmpdir = tempdir(TEMPLATE => $tmp_path.'/fstar.XXXXXX', CLEANUP => 1);
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-p/) { $prj = shift; chomp($prj);} #nombre local del proyecto
    if (/^-x/) { $xprj = shift; chomp($xprj);} #nombre del proyecto en XNAT
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-ovw/) {$overwrite = 1;}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/xnat_getfs.hlp'; exit;}
}
$xprj = $prj unless $xprj;
die "Should supply project name\n" unless $xprj;
my %std = load_project($prj);
if(exists($std{'XNAME'}) and $std{'XNAME'}){
	$xprj = $std{'XNAME'};
}
my $proj_file = $std{'DATA'}.'/'.$prj.'_mri.csv';
my %guys = populate('^(\d{4});(.*)$', $proj_file);
my %rguys;
my @cuts;
if ($cfile){
	open IDF, "<$cfile" or die "No such input file!\n";
	@cuts = <IDF>;
	chomp @cuts;
	close IDF;
	foreach my $guy (sort keys %guys){
		if( grep {/$guys{$guy}/} @cuts){
			$rguys{$guys{$guy}} = $guy;
		}
	}
}else{
	foreach my $guy (sort keys %guys){
		$rguys{$guys{$guy}} = $guy;
	}
}
my %xconfig = xget_session();
# Saco los sujetos del proyecto
print "Getting XNAT subject list\n";
my $jid = $xconfig{'JSESSION'};
my %subjects = xget_subjects($xconfig{'HOST'}, $jid, $xprj);
# Lets sort the data;
my %psubjects;
open DDF, ">$debug";
foreach my $xsbj (sort keys %subjects) {
	if (exists($rguys{$subjects{$xsbj}{'label'}})){
		$psubjects{$xsbj}{'Subject'} = $subjects{$xsbj}{'label'};
		$psubjects{$xsbj}{'PSubject'} = $rguys{$subjects{$xsbj}{'label'}};
		print DDF "$psubjects{$xsbj}{'Subject'},$psubjects{$xsbj}{'PSubject'}\n";
	}	
}
close DDF;
# Para cada sujeto saco el ID de experimento de la MRI
foreach my $xsbj (sort keys %psubjects){
	#$psubjects{$xsbj}{'MRI'} 
	my @list_mri = xget_mri($xconfig{'HOST'}, $jid, $xprj, $xsbj);
	$psubjects{$xsbj}{'MRI'} = $list_mri[0];
}
# Ya teniendo los experimentos emparejo los sujetos segun codigo de proyecto local, codigo de XNAT y experimento de XNAT
# Y ahora voy a bajar todo el tgz para cada imagen y descomprimirla dentro del directorio
# de sujetos de Freesurfer, con la convencion PROYECTO_IDLOCALSUJETO, tal y como hace el 
# pipeline local. A partir de aqui se pueden ejecutar las operaciones que se deseen, como si
# se hubiera hecho todo el procesamiento localmente.
print "OK, now I'm going on\nDownloading and extracting\n";
my $outdir = $std{'DATA'}.'/slurm';
mkdir $outdir;
my %ptask = ('job_name' => 'fake_FS_'.$prj);
my @jobs;
foreach my $xsbj (sort keys %psubjects){
	my $fsdir = $ENV{'SUBJECTS_DIR'}."/".$prj."_".$psubjects{$xsbj}{'PSubject'};
	unless ( -d $fsdir and not $overwrite){
		my $tfsdir = $tmpdir."/".$prj."_".$psubjects{$xsbj}{'PSubject'};
		#mkdir $tfsdir;
		mkdir $fsdir;
		my $tfsout = $tfsdir.'/'.$xsbj.'.tar.gz';
		my %fs_files = xlist_res($xconfig{'HOST'}, $jid, $psubjects{$xsbj}{'MRI'}, 'FS');
		foreach my $fsfile (sort keys %fs_files){
			if ($fsfile =~ /.*\.tar\.gz$/){
				$ptask{'output'} = $outdir.'/'.$psubjects{$xsbj}{'PSubject'}.'.out';
				$ptask{'filename'} = $outdir.'/'.$psubjects{$xsbj}{'PSubject'}.'.sh';
				print "$fsfile -> $fsdir\n";
				$ptask{'command'} = 'mkdir '.$tfsdir."\n";
				$ptask{'command'} .= xget_res_file($xconfig{'HOST'}, $jid, $psubjects{$xsbj}{'MRI'}, 'FS', $fsfile,  $tfsout, 1);
				$ptask{'command'} .= "\n";
				$ptask{'command'} .= "tar xzf ".$tfsout." -C ".$fsdir."/ --transform=\'s/".$xsbj."//\' --exclude=\'fsaverage\' \n";
				$ptask{'command'} .='rm -rf '.$tfsdir."\n";
				#dump %ptask;
				send2slurm(\%ptask);
			}
		}
	}
}
my %warn = ('job_name' => 'fake_FS_'.$prj, 
	'filename' => $outdir.'/fake_FS_end.sh', 
	'mailtype' => 'END',
	'output' => $outdir.'/fakefs_end',
	'dependency' => 'singleton'
);
send2slurm(\%warn);
