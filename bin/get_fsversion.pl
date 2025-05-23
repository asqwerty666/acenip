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

# Aqui voy a reutilizar el xnat_pullfs.pl para bajar el aseg.stats 
# y extraer la version de freesurfer con la que se ha hecho el procesamiento 


use strict; use warnings;
use NEURO4 qw(populate get_subjects check_fs_subj load_project print_help check_or_make cut_shit);
use FSMetrics qw(fs_file_metrics);
use XNATACE qw(xget_session xget_subjects xget_mri xget_sbj_data xget_res_file xget_exp_data);
use File::Basename qw(basename);
use File::Slurp qw(read_file);
use File::Temp qw(tempdir);
use Data::Dump qw(dump);

my $stats = "aseg";
my $all = 0;
my $prj;
my $xprj;
my $tmp_dir = $ENV{'TMPDIR'};
my $tmpdir = tempdir(TEMPLATE => $tmp_dir.'/fs.XXXXX', CLEANUP => 1); 
my $ofile;
my $ifile;
my $with_date = 1;
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-i/) {$ifile = shift; chomp($ifile);}
    #    if (/^-d/) { $with_date = 1; }
    if (/^-o/) { $ofile = shift; chomp($ofile);}
    if (/^-p/) { $prj = shift; chomp($prj);} #nombre local del proyecto
    if (/^-x/) { $xprj = shift; chomp($xprj);} #nombre del proyecto en XNAT
    if (/^-h/) {
	   print "Get XNAT experiment ID and FS version of MRI analysis\n";
	   print "usage: $0 [-o <ouput file>] [-i <cut file>] -p <local project name> [-x <xnat project name>]\n"; 
	   exit;
    }
}

my %std;
if ($prj and not $xprj) {
        %std = load_project($prj);
	if(exists($std{'XNAME'}) and $std{'XNAME'}){
	        $xprj = $std{'XNAME'};
	}
}
die "Should supply XNAT project name or define it at local project config!\n" unless $xprj;
my @cuts; 
if ($ifile){ 
	open IDF, "<$ifile" or die "No such input file!\n"; 
	@cuts = <IDF>; 
	chomp @cuts; 
	close IDF; 
}
my %subjects = xget_subjects($xprj);
my %psubjects;
foreach my $xsbj (sort keys %subjects){
	$psubjects{$xsbj}{'MRI'} = [ xget_mri($xprj, $xsbj) ];
}
# Ahora voy a bajar el archivo de stats para cada imagen y dentro de un directorio
# para cada sujeto, con la convencion IDSUJETOXNAT. 
# De aqui he de extraer las estadisticas que se han pedido
# y dejarlas en un archivo.
my @fsnames;
my $fsout = $tmpdir.'/fsresults';
mkdir $fsout unless -d $fsout;
my $okheader = 0;
open STDOUT, ">$ofile" unless not $ofile;
foreach my $subject (sort keys %psubjects){
	# Primero voy a ir sacando los IDs de sujeto y experimentos que he capturado
	# Hago un directorio para cada uno
	foreach my $experiment (@{$psubjects{$subject}{'MRI'}}){
		my $getthis = 1;
		if ($ifile) {
			$getthis = 0 unless grep {/$experiment/} @cuts;
		}	
		my $order = 'mkdir -p '.$fsout.'/'.$subject.'/'.$experiment.'/stats';
		system($order);
		# ahora voy a intentar sacar las estadisticas
		# y guardo el archivo de stats
		my $tmp_out = $fsout.'/'.$subject.'/'.$experiment.'/stats/'.$stats.'.stats';
		xget_res_file($experiment, 'FS', $stats.'.stats' , $tmp_out);
		# Aqui voy a sacar los volumenes porque son distintos a los demas
		if( -f $tmp_out){
			my $tdata = `grep "cvs_version" $tmp_out | awk '{print \$3}'`;
			chomp $tdata; 
			unless($okheader) {
				print "experiment,version\n";
				$okheader = 1;
			}
			print "$experiment,$tdata\n";
		}
	}
}
close STDOUT;
