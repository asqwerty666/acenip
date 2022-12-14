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

# v0.1 - extraer aseg -> done
# v0.2 - extraer aparc -> done
# v0.3 - remove external dependencies -> done


use strict; use warnings;
use NEURO4 qw(populate get_subjects check_fs_subj load_project print_help check_or_make cut_shit);
use FSMetrics qw(fs_file_metrics);
use XNATACE qw(xget_conf xget_session xget_subjects xget_mri xget_sbj_data xget_fs_stats xget_exp_data);
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
my $with_date = 0;
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-s/) { $stats = shift;}
    if (/^-d/) { $with_date = 1; }
    if (/^-o/) { $ofile = shift; chomp($ofile);}
    if (/^-p/) { $prj = shift; chomp($prj);} #nombre local del proyecto
    if (/^-x/) { $xprj = shift; chomp($xprj);} #nombre del proyecto en XNAT
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/xnat_pullfs.hlp'; exit;}
}
my %std;
if ($prj and not $xprj) {
        %std = load_project($prj);
	if(exists($std{'XNAME'}) and $std{'XNAME'}){
	        $xprj = $std{'XNAME'};
	}
}
die "Should supply XNAT project name or define it at local project config!\n" unless $xprj;
# Saco los sujetos del proyecto 
my %xconfig = xget_session();
my $jid = $xconfig{'JSESSION'};
my %subjects = xget_subjects($xconfig{'HOST'}, $jid, $xprj);
my %psubjects;
foreach my $xsbj (sort keys %subjects){
	$psubjects{$xsbj}{'MRI'} = xget_mri($xconfig{'HOST'}, $jid, $xprj, $xsbj);
	$psubjects{$xsbj}{'label'} = xget_sbj_data($xconfig{'HOST'}, $jid, $xsbj, 'label');
	$psubjects{$xsbj}{'date'} = xget_exp_data($xconfig{'HOST'}, $jid, $psubjects{$xsbj}{'MRI'}, 'date') if $with_date;
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
	my $order = 'mkdir -p '.$fsout.'/'.$subject.'/stats';
	system($order);
	# ahora voy a intentar sacar las estadisticas
	if($stats eq "aseg"){
		# y guardo el archivo de stats
		my $tmp_out = $fsout.'/'.$subject.'/stats/'.$stats.'.stats';
		xget_fs_stats($xconfig{'HOST'}, $jid, $psubjects{$subject}{'MRI'}, 'aseg.stats' , $tmp_out);
		# Aqui voy a sacar los volumenes porque son distintos a los demas
		if( -f $tmp_out){
			my @tdata = `grep -v "^#" $tmp_out | awk '{print \$5","\$4}'`;
			chomp @tdata; 
			my %udata = map { my ($key, $value) = split ","; $key => $value } @tdata;
			my $etiv = `grep  EstimatedTotalIntraCranialVol $tmp_out | awk -F", " '{print \$4}'`;
			chomp $etiv;
			unless($okheader) {
				print 'Subject_ID';
				print ',Date' if $with_date;
				foreach my $dhead (sort keys %udata){
					print ",$dhead";
				}
				$okheader = 1;
				print ",eTIV\n";
			}
			print "$psubjects{$subject}{'label'}";
			print ",$psubjects{$subject}{'date'}" if $with_date;
			foreach my $roi (sort keys %udata){
				print ",$udata{$roi}";
			}
			print ",$etiv\n";
		}
	}elsif($stats eq "aparc"){
		# Aqui voy a sacar las aparc. Esto es la parcelacion del cortex
		# y hay dos archivos distintos lh.aparc.stats y rh.aparc.stats
		# asi que tengo que sacar los hemisferios por separados
		my @hemis = ('lh', 'rh');
		my @meassures = ('SurfArea', 'GrayVol', 'ThickAvg');
		my $etiv;
		my $ctx_thick;
		my $ctx_vol;
		my %udata;
		my $go=0;
		foreach my $hemi (@hemis){
			my $tmp_out = $fsout.'/'.$subject.'/stats/'.$hemi.'.'.$stats.'.stats';
			xget_fs_stats($xconfig{'HOST'}, $jid, $psubjects{$subject}{'MRI'}, $hemi.'.'.$stats.'.stats' , $tmp_out);
			if (-f $tmp_out) {
				my @tdata = `grep -v "^#" $tmp_out | awk '{print \$1","\$3","\$4","\$5}'`;
				chomp @tdata;
				foreach my $chunk (@tdata) {
					my ($key, $sa, $gv, $tv) = split /,/, $chunk; 
					$udata{$hemi}{$key}{'SurfArea'} = $sa;
					$udata{$hemi}{$key}{'GrayVol'} = $gv;
					$udata{$hemi}{$key}{'ThickAvg'} = $tv;
				}
				$etiv = `grep  EstimatedTotalIntraCranialVol $tmp_out | awk -F", " '{print \$4}'`;
				$ctx_thick = `grep MeanThickness $tmp_out | awk -F", " '{print \$4}'`;
				$ctx_vol = `grep CortexVol $tmp_out | awk -F", " '{print \$4}'`;
				chomp $etiv;
				chomp $ctx_thick;
				chomp $ctx_vol;
				$go = 1;
			}
		}
		if ($go){
			unless($okheader) {
				print "Subject_ID";
				print ',Date' if $with_date;
				foreach my $hemi (@hemis){
					foreach my $dhead (sort keys %{$udata{$hemi}}){
						foreach my $measure (@meassures){
							print ",$hemi.$dhead.$measure";
						}
					}
				}
				$okheader = 1;
				print ",eTIV,Cortex_Thickness,Cortex_Volume\n";
			}
			print "$psubjects{$subject}{'label'}";
			print ",$psubjects{$subject}{'date'}" if $with_date;
			foreach my $hemi (@hemis){
				foreach my $dhead (sort keys %{$udata{$hemi}}){
					foreach my $measure (@meassures){
						print ",$udata{$hemi}{$dhead}{$measure}";
					}
				}
			}
			print ",$etiv,$ctx_thick,$ctx_vol\n";
		}
	}
}
close STDOUT;
