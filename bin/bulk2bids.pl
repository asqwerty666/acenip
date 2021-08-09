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
use SLURM qw(send2slurm);
my $cfile = 'bids/conversion.json';
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-c/) { $cfile = shift; chomp($cfile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/bulk2bids.hlp'; exit;}
}
my $proj  = shift;
# leo la configuacion del proyecto
unless ($proj) { print_help $ENV{'PIPEDIR'}.'/doc/bulk2bids.hlp'; exit;}
my %std = load_project($proj);
my $src_dir = $std{'SRC'};
my $proj_file = $std{'DATA'}.'/'.$proj.'_mri.csv';
my %guys = populate('^(\d{4});(.*)$', $proj_file);
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);
# defino las propiedas generales de la tarea en el schedule manager
my %ptask;
$ptask{'cpus'} = 8;
$ptask{'job_name'} = 'dcm2bids_'.$proj;
$ptask{'time'} = '3:0:0';
$ptask{'mem_per_cpu'} = '4G';
foreach my $subject (sort keys %guys) {
	$ptask{'command'} = "mkdir -p $std{'DATA'}/bids/tmp_dcm2bids/sub-$subject; dcm2niix -b y -ba y -z y -f '%3s_%f_%p_%t' -o $std{'DATA'}/bids/tmp_dcm2bids/sub-$subject $std{'SRC'}/$guys{$subject}/; dcm2bids -d $std{'SRC'}/$guys{$subject}/ -p $subject -c $std{'DATA'}/$cfile -o $std{'DATA'}/bids/";
	$ptask{'filename'} = $outdir.'/'.$subject.'dcm2bids.sh';
	$ptask{'output'} = $outdir.'/dcm2bids'.$subject.'-%j';
	send2slurm(\%ptask);
}
my %warn;
$warn{'filename'} = $outdir.'/dcm2bids_end.sh';
$warn{'job_name'} = 'dcm2bids_'.$proj;
$warn{'mailtype'} = 'END'; #email cuando termine
$warn{'output'} = $outdir.'/dmc2bids_end-%j';
$warn{'dependency'} = 'singleton';
send2slurm(\%warn);

