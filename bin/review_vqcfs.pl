#!/usr/bin/perl

# Copyright 2019 O. Sotolongo <asqwerty@gmail.com>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# Now, this is a tricky shit. Here you may have downloaded the 
# project FS data into a subdirectory (or not) and you are going to 
# launch the visualqc tool as expected if there is no revision yet
# However, when finished you will upload the results only for the 
# revise ones.
#
# Yep, is a mess but I should allow to people to revise the QC 
# without work across an entire project
#
# Also, this script depends on xnatapic tool that is a private ACE tool.
# So this is difficult to add to another pipelines. \(_ _)/ 
#

use strict; use warnings;
use Cwd qw(cwd);
use NEURO4 qw(load_project print_help populate check_or_make getLoggingTime);

my $prj;
my $xprj;
my $ifile; my $efile;
my $wdir = cwd;
my $odir;
my $continue = 0; 

@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-i/) { $ifile = shift; chomp($ifile);}
	if (/^-d/) { $odir = shift; chomp($odir);}
	if (/^-c/) { $continue = 1;}
	if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/reviewqc.hlp'; exit;}
	if (/^-x/) { $xprj = shift; chomp($xprj);} #nombre del proyecto en XNAT
	if (/^-p/) { $prj = shift; chomp($prj);} #nombre local del proyecto
}

# Mira, hay que meter el proyecto de XNAT con alguno de los dos switch
$xprj = $prj unless $xprj;
# O te vas a tomar por culo
die unless $xprj;
# You must be under X11 to run this shit
die "Should run this under X!\n" unless $ENV{'DISPLAY'};

# y entonces, el file de input es el que tu digas o los tendras que mirar todos
# Estos son los experimentos a los que vamos a revisar o hacer el QC. 
# Puedes tomar la lista completa y reducirla a lo que quieres o simplemente 
# tomar la lista as is
my @pollos;
$efile=$wdir.'/'.$xprj.'_experiment.list';
if ($ifile and -f $ifile){
	$efile=$wdir.'/'.$xprj.'_experiment_custom.list';
	open IDF, "<$ifile";
	@pollos = <IDF>; chomp @pollos;
	close IDF;
	open TDF, ">$efile";
	foreach my $pollo (@pollos){
		my $look = "xnatapic list_experiments --project_id $xprj --subject_id $pollo --modality MRI";
		my $epollo = qx/$look/;
		chomp $epollo;
		print TDF "$epollo\n";
	}
	close TDF;
}
unless ($odir and -d $odir) {
	# si me das un directorio de input y este existe entonces no tengo que 
	# bajarme nada sino hacer el analisis a partir de este directorio
	# Si no me das el dir que tengo que leer pero el default ya existe entonces 
	# creo uno nuevo con el timestamp y ese es el que voy a usar
	$odir=$wdir.'/'.$xprj.'_fsresults';
	if ( -d $odir ){
		# a no ser que exista, entonces muevo este a otro sitio
		# y creo uno nuevo con el timestamp
		$odir = $odir.'_'.getLoggingTime();
	}
	mkdir $odir;
	#y ejecuto la preparacion
	if ($ifile and -f $ifile){
		# si me has dado una lista de los que quieres procesar
		# me limito a preparar esos
		foreach my $pollo (@pollos){
			my $pre = "xnatapic prepare_fsqc --project_id $xprj --outdir $odir --subject_id $pollo";
			system($pre);
		}
	}else{	
		#pero si no hay lista los bajo todos
		my $pre = "xnatapic prepare_fsqc --project_id $xprj --outdir $odir";
		system($pre);
	}
}

my $vqcd = $wdir.'/visualqc_output';
if ( -d $vqcd ){
	#aqui igual, si existe el directorio de output 
	#no lo sobreescribo sino que le añado el timestamp al nuevo
	unless ($continue) {
		$vqcd = $vqcd.'_'.getLoggingTime();
		mkdir $vqcd;
	}
}else{
	mkdir $vqcd;
}
# y ahora es que lanzamos el visualQC con las opciones que hemos leido o creado
if ($ifile and -f $ifile){
	my $order = "vqcfs -i $efile -f $odir -o $vqcd";
	system($order);
}else{
	my $order = "vqcfs -f $odir -o $vqcd";
	system($order);
}
#por ultimo subimos los resultados que haya
my $post = "xnatapic upload_fsqc --qcdir $vqcd";
system($post);
