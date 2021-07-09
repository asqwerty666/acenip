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

use strict; use warnings;
use NEURO4 qw(load_project print_help populate check_or_make);

my $cfile = 'bids/conversion.json';
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-c/) { $cfile = shift; chomp($cfile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/bulk2bids.hlp'; exit;}
}
my $proj  = shift;
unless ($proj) { print_help $ENV{'PIPEDIR'}.'/doc/bulk2bids.hlp'; exit;}
my %std = load_project($proj);
my $src_dir = $std{'SRC'};
my $proj_file = $std{'DATA'}.'/'.$proj.'_mri.csv';
my %guys = populate('^(\d{4});(.*)$', $proj_file);
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);
foreach my $subject (sort keys %guys) {
	my $order = "mkdir -p $std{'DATA'}/bids/tmp_dcm2bids/sub-$subject; dcm2niix -b y -ba y -z y -f '%3s_%f_%p_%t' -o $std{'DATA'}/bids/tmp_dcm2bids/sub-$subject $std{'SRC'}/$guys{$subject}/; dcm2bids -d $std{'SRC'}/$guys{$subject}/ -p $subject -c $std{'DATA'}/$cfile -o $std{'DATA'}/bids/";
	#print "$order\n";
	my $orderfile = $outdir.'/'.$subject.'dcm2bids.sh';
	open ORD, ">$orderfile";
	print ORD '#!/bin/bash'."\n";
	print ORD '#SBATCH -J dcm2bids_'.$proj."\n";
	print ORD '#SBATCH --time=3:0:0'."\n"; #si no ha terminado en X horas matalo
	print ORD '#SBATCH --mail-type=FAIL,TIME_LIMIT,STAGE_OUT'."\n"; #no quieres que te mande email de todo
	print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
	print ORD '#SBATCH -p fast'."\n";
        print ORD '#SBATCH -c 8'."\n";
	print ORD '#SBATCH --mem-per-cpu=4G'."\n";
	print ORD '#SBATCH -o '.$outdir.'/dcm2bids'.$subject.'-%j'."\n";
	print ORD "srun $order\n";
	close ORD;
	system("sbatch $orderfile");
}
my $orderfile = $outdir.'/dcm2bids_end.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J dcm2bids_'.$proj."\n";
print ORD '#SBATCH --mail-type=END'."\n"; #email cuando termine o falle
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -o '.$outdir.'/dmc2bids_end-%j'."\n";
print ORD ":\n";
close ORD;
my $xorder = 'sbatch --dependency=singleton'.' '.$orderfile;
exec($xorder);

