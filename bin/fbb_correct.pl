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

# Este script se encarga de buscar los PETs que estan en el directorio BIDS
# del proyecto, y registrarlos a espacio nativo T1w utilizando el MRI
# correspondiente.
#
# Las opciones (-nocorr) permiten escoger entre archivos PET 4D con imagenes 4x5min (single)
# o archivos 3D con imagenes de 20min (combined)
use strict; use warnings;
use Data::Dump qw(dump);
use File::Find::Rule;
use File::Copy::Recursive qw(dirmove);

use NEURO4 qw(check_pet check_subj load_project print_help check_or_make cut_shit);

#my $study;
my $cfile="";
my $sok = 0;
my $movcor = 1;
my $alt = 0;
my $time = '8:0:0';
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    #if (/^-e/) { $study = shift; chomp($study);}
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-nocorr/) {$movcor = 0;}
    if (/^-alt/) {$alt = 1;}
    if (/^-time/) {$time = shift; chomp($time)}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/fbb_reg.hlp'; exit;}
}
my $study = shift;
# Cargo las opciones del proyecto
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/fbb_reg.hlp'; exit;}
my %std = load_project($study);
my $subj_dir = $ENV{'SUBJECTS_DIR'};
my $w_dir=$std{'WORKING'};
my $db = $std{'DATA'}.'/'.$study.'_pet.csv';
my $data_dir=$std{'DATA'};
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

print "Collecting needed files\n";
my @pets = cut_shit($db, $data_dir.'/'.$cfile);
# Defino los call a SLURM
my %ptask = ( 'job_name' => 'fbb_reg_'.$study,
	'time' => $time,
	'mem_per_cpu' => '4G',
	'mailtype' => 'FAIL,STAGE_OUT',
);
foreach my $subject (@pets){
	# Tienen que existir tanto el PET como el MRI
	my %spet = check_pet($std{'DATA'},$subject);
	my %smri = check_subj($std{'DATA'},$subject); 
	unless ($movcor){
		# Ahora si $movcor == 0 tomo el combined y hago un registro simple
                if($spet{'combined'} && $smri{'T1w'}){
			my $order;
			if ($alt){
				# Esto no deberia usarse a no ser que hubiera muchos problemas con el registro
				# Pero se puede hacer un rupo aparte e intentar este metodo
				# si no se logra registrar bien
                        	$order = $ENV{'PIPEDIR'}."/bin/fbb_reg_alt.sh ".$study." ".$subject." ".$w_dir." ".$spet{'combined'}." ".$smri{'T1w'}." 0";
			}else{
				$order = $ENV{'PIPEDIR'}."/bin/fbb_reg.sh ".$study." ".$subject." ".$w_dir." ".$spet{'combined'}." ".$smri{'T1w'}." 0";
			}
			$ptask{'command'} = $order;
                        $ptask{'filename'} = $outdir.'/'.$subject.'_fbb_reg.sh';
			$ptask{'cpus'} = 8;
			$ptask{'output'} = $outdir.'/fbb_reg_'.$subject;
			send2slurm(\%ptask);
		}
	}else{
		# Pero si movcorr == 1 tomo el single y hago la correcion de movimiento
		if($spet{'single'} && $smri{'T1w'}){
			$ptask{'command'} = $ENV{'PIPEDIR'}."/bin/fbb_reg.sh ".$study." ".$subject." ".$w_dir." ".$spet{'single'}." ".$smri{'T1w'}." 1";
			$ptask{'filename'} = $outdir.'/'.$subject.'_fbb_reg.sh';
			$ptask{'cpus'} = 4;
			$ptask{'output'} = $outdir.'/fbb_reg_'.$subject;
			send2slurm(\%ptask);
		}
	}
}
# Y aqui saco el report al final
my %final = ( 'command' => $ENV{'PIPEDIR'}."/bin/make_fbb_report.pl ".$study,
	'filename' => $outdir.'/fbb_report.sh',
	'job_name' => 'fbb_reg_'.$study,
	'time' => '2:0:0',
	'mailtype' => 'FAIL,END',
	'output' => $outdir.'/fbb_report',
	'dependency' => 'singleton',
);
send2slurm(\%final);
