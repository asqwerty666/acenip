#!/usr/bin/perl

# Copyright 2020 O. Sotolongo <asqwerty@gmail.com>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# Aqui se bajan los resultados del analisis de FS de XNAT con el objetivo, no de
# tener una estructura local sino de extraer directamente un grupos de datos
# de la segmentacion

# v0.1 - extraer aseg
# v0.2 - extraer aparc

use strict; use warnings;
use NEURO4 qw(populate get_subjects check_fs_subj load_project print_help check_or_make cut_shit);
use FSMetrics qw(fs_file_metrics);
use File::Basename qw(basename);
use File::Slurp qw(read_file);

my $stats = "aseg";
my $all = 0;
my $prj;
my $xprj;
my $tmpdir; 
chomp($tmpdir = `mktemp -d /tmp/fstar.XXXXXX`);
my $guide = $tmpdir."/xnat_guys.list";
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-s/) { $stats = shift;}
    if (/^-p/) { $prj = shift; chomp($prj);} #nombre local del proyecto
    if (/^-x/) { $xprj = shift; chomp($xprj);} #nombre del proyecto en XNAT
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/xnat_get.hlp'; exit;}
}
unless ($prj) { print_help $ENV{'PIPEDIR'}.'/doc/xnat_get.hlp'; exit;}
$xprj = $prj unless $xprj;
my %std = load_project($prj);
# La parte inicial es comun con xnat_pullfs.pl (a lo mejor meterlo en una funcion?)
# Saco los sujetos del proyecto 
my $order = "xnatapic list_subjects --project_id ".$xprj." --label > ".$std{'DATA'}."/xnat_subjects.list";
print "Getting XNAT subject list\n";
system($order);
# Para cada sujeto saco el ID de experimento de la MRI
$order = "for x in `awk -F\",\" {'print \$1'} xnat_subjects.list`; do e=\$(xnatapic list_experiments --project_id ".$xprj." --subject_id \${x} --modality MRI); if [[ \${e} ]]; then echo \"\${x},\${e}\"; fi; done > ".$std{'DATA'}."/xnat_subject_mri.list";
print "Getting experiments\n";
system($order);
# Ya teniendo los experimentos emparejo los sujetos segun codigo de proyecto local, codigo de XNAT y experimento de XNAT
my $proj_file = $std{'DATA'}.'/'.$prj.'_mri.csv';
$order = "sed 's/;/,/g' ".$proj_file." > ".$tmpdir."/all_mri.list;"; 
$order.= "sort -t, -k 2 ".$tmpdir."/all_mri.list > ".$tmpdir."/all_mri_sorted.list;";
$order.= "join -t, xnat_subjects.list xnat_subject_mri.list > ".$tmpdir."/tmp_mri.list;";
$order.= "sort -t, -k 2 ".$tmpdir."/tmp_mri.list > ".$tmpdir."/xnat_tmp_mri_sorted.list;";
$order.= "join -t, -j 2 ".$tmpdir."/all_mri_sorted.list ".$tmpdir."/xnat_tmp_mri_sorted.list  > ".$tmpdir."/xnat_guys.list";
print "Sorting, joining, keeping shit together\n";
system($order);
# Ahora voy a bajar el archivo de stats para cada imagen y dentro de un directorio
# para cada sujeto, con la convencion IDSUJETOXNAT. 
# De aqui he de extraer las estadisticas que se han pedido
# y dejarlas en un archivo.
my @fsnames;
my $fsout = $std{DATA}.'/fsresults';
mkdir $fsout unless -d $fsout;
open IDF, "<$guide" or die "No such file or directory\n";
my $okheader = 0;
while(<IDF>){
	my $ofile = $std{DATA}.'/'.$prj.'_'.$stat.'.csv';
	open ODF, ">ofile";
	# Primero voy a ir sacando los IDs de sujeto y experimentos que he capturado
	my ($pid, $imgid, $xsubj, $xexp) = /(.*),(.*),(.*),(.*)/;
	# Hago un directorio para cada uno
	my $order = 'mkdir -p '.$fsout.'/'.$xsubj.'/stats';
	system($order);
	# y guardo el archivo de stats
	$order = 'xnatapic get_fsresults --experiment_id '.$xexp.' --stats '.$stats.' '.$fsout.'/'.$xsubj.'/';
	print "$order\n";
	system($order);
	# ahora voy a intentar sacar las estadisticas
	if($stat == "aseg"){
		# Aqui voy a sacar los volumenes porque son distintos a los demas
		my @tdata = `grep -v "^#" $fsout/$xsubj/$stat.stats | awk '{print \$5","\$4}'`;
		chomp @tdata;
		my %udata = map { my ($key, $value) = split ","; $key => $value } @tdata;
		my $etiv = `grep  EstimatedTotalIntraCranialVol $fsout/$xsubj/$stat.stats | awk -F", " '{print $4}'`;
		#$udata{'eTIV'} = $etiv;
		unless($okheader) {
			print ODF "Subject_ID";
			foreach my $dhead (sort keys %udata){
				print ODF ", $dhead";
			}
			$okheader = 1;
			print ODF ", eTIV\n";
		}
		print ODF "$pid";
		foreach my $roi sort keys %udata){
			print ", $udata{$roi}";
		}
		print ", $eitv\n";
	}
}
my $order = 'rm -rf '.$fsout;
system($order);
