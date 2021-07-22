#!/usr/bin/perl
#Copyright 2021 O. Sotolongo <asqwerty@gmail.com>

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
# y los copia localmente en una nativa ed Freesurfer.
# Esto es util para realizar procedimientos posteriores 
# como los analisis FSGA o longitudinales, o simplemente un QC

use strict;
use warnings;
use NEURO4 qw(load_project print_help populate check_or_make);

my $prj;
my $xprj;
my $tmpdir; 
chomp($tmpdir = `mktemp -d /tmp/fstar.XXXXXX`);
my $guide = $tmpdir."/xnat_guys.list";
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-p/) { $prj = shift; chomp($prj);} #nombre local del proyecto
    if (/^-x/) { $xprj = shift; chomp($xprj);} #nombre del proyecto en XNAT
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/xnat_pull.hlp'; exit;}
}
$xprj = $prj unless $xprj;
my %std = load_project($prj);
# Saco los sujetos del proyecto 
# Nota: Esto demora mucho, habria que revisarlo y ver si se puede cambiar la metodologia en xnatapic
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
# Y ahora voy a bajar todo el tgz para cada imagen y descomprimirla dentro del directorio
# de sujetos de Freesurfer, con la convencion PROYECTO_IDLOCALSUJETO, tal y como hace el 
# pipeline local. A partir de aqui se pueden ejecutar las operaciones que se deseen, como si
# se hubiera hecho todo el procesamiento localmente.
print "OK, now I'm going on\nDownloading and extracting\n";
open IDF, "<$guide" or die "No such file or directory\n";
while(<IDF>){
	my ($pid, $imgid, $xsubj, $xexp) = /(.*),(.*),(.*),(.*)/;
	my $fsdir = $ENV{'SUBJECTS_DIR'}."/".$prj."_".$imgid;
	unless ( -d $fsdir){
		my $tfsdir = $tmpdir."/".$prj."_".$imgid;
		mkdir $tfsdir;
		my $xorder = "xnatapic get_fsresults --experiment_id ".$xexp." --all-tgz ".$tfsdir;
		print "$xorder\n";
		system($xorder);
		mkdir $fsdir;
		my $order = "tar xzvf ".$tfsdir."/*.tar.gz -C ".$fsdir."/ --transform=\'s/".$xsubj."//\' --exclude=\'fsaverage\'";
		print "$order\n";
		system($order);
	}
}
$order = "rm -rf ".$tmpdir;
system($order);
