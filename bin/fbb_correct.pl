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
#
use strict; use warnings;
use Data::Dump qw(dump);
use File::Find::Rule;
use File::Copy::Recursive qw(dirmove);

use NEURO4 qw(check_pet check_subj load_project print_help check_or_make cut_shit);

#my $study;
my $cfile="";
my $sok = 0;
my $onlyone = 1;
my $alt = 0;
my $time = '8:0:0';
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    #if (/^-e/) { $study = shift; chomp($study);}
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-wcorr/) {$onlyone = 0;}
    if (/^-alt/) {$alt = 1;}
    if (/^-time/) {$time = shift; chomp($time)}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/fbb_reg.hlp'; exit;}
}
my $study = shift;
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

foreach my $subject (@pets){
	my %spet = check_pet($std{'DATA'},$subject);
	my %smri = check_subj($std{'DATA'},$subject);
	#dump %spet; dump %smri;
	if ($onlyone){
                if($spet{'combined'} && $smri{'T1w'}){
			my $order;
			if ($alt){
                        	$order = $ENV{'PIPEDIR'}."/bin/fbb_reg_alt.sh ".$study." ".$subject." ".$w_dir." ".$spet{'combined'}." ".$smri{'T1w'}." 0";
			}else{
				$order = $ENV{'PIPEDIR'}."/bin/fbb_reg.sh ".$study." ".$subject." ".$w_dir." ".$spet{'combined'}." ".$smri{'T1w'}." 0";
			}
                        my $orderfile = $outdir.'/'.$subject.'_fbb_reg.sh';
                        open ORD, ">$orderfile";
                        print ORD '#!/bin/bash'."\n";
                        print ORD '#SBATCH -J fbb_reg_'.$study."\n";
                        print ORD '#SBATCH --time='.$time."\n"; #si no ha terminado en X horas matalo
                        print ORD '#SBATCH --mail-type=FAIL,STAGE_OUT'."\n"; #no quieres que te mande email de todo
                        print ORD '#SBATCH -o '.$outdir.'/fbb_reg_'.$subject.'-%j'."\n";
                        print ORD '#SBATCH -c 8'."\n";
                        print ORD '#SBATCH --mem-per-cpu=4G'."\n";
                        print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
                        print ORD "srun $order\n";
                        close ORD;
                        system("sbatch $orderfile");
		}
	}else{
		if($spet{'single'} && $smri{'T1w'}){
			my $order = $ENV{'PIPEDIR'}."/bin/fbb_reg.sh ".$study." ".$subject." ".$w_dir." ".$spet{'single'}." ".$smri{'T1w'}." 1";
			my $orderfile = $outdir.'/'.$subject.'_fbb_reg.sh';
			open ORD, ">$orderfile";
			print ORD '#!/bin/bash'."\n";
			print ORD '#SBATCH -J fbb_reg_'.$study."\n";
			print ORD '#SBATCH --time='.$time."\n"; #si no ha terminado en X horas matalo
			print ORD '#SBATCH --mail-type=FAIL,STAGE_OUT'."\n"; #no quieres que te mande email de todo
			print ORD '#SBATCH -o '.$outdir.'/fbb_reg_'.$subject.'-%j'."\n";
			print ORD '#SBATCH -c 4'."\n";
			print ORD '#SBATCH --mem-per-cpu=4G'."\n";
			print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
			print ORD "srun $order\n";
			close ORD;
			system("sbatch $orderfile");
		}
	}
}

my $order = $ENV{'PIPEDIR'}."/bin/make_fbb_report.pl ".$study;
my $orderfile = $outdir.'/fbb_report.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J fbb_reg_'.$study."\n";
print ORD '#SBATCH --time=2:0:0'."\n"; #si no ha terminado en X horas matalo
print ORD '#SBATCH --mail-type=FAIL,END'."\n"; #email cuando termine o falle
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -o '.$outdir.'/fbb_report-%j'."\n";
print ORD "srun $order\n";
close ORD;

my $xorder = 'sbatch --dependency=singleton'.' '.$orderfile;
exec($xorder);

