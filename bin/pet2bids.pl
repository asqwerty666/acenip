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

# Este script toma los DCM de imagen PET y los lleva a NIfTI,
# almacenados en formato BIDS
use strict; use warnings;
use NEURO4 qw(load_project print_help populate check_or_make);
use SLURMACE qw(send2slurm);
use Data::Dump qw(dump);
my $cfile = 'bids/conversion.json';
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-c/) { $cfile = shift; chomp($cfile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/pet2bids.hlp'; exit;}
}
my $proj  = shift;
unless ($proj) { print_help $ENV{'PIPEDIR'}.'/doc/pet2bids.hlp'; exit;}
my %std = load_project($proj);
my $src_dir = $std{'PET'};
my $proj_file = $std{'DATA'}.'/'.$proj.'_pet.csv';
die "There is'nt pet list file!\n" unless -f $proj_file;
my %guys = populate('^(\d{4});(.*)$', $proj_file);
#dump %guys;
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);
my %ptask;
$ptask{'job_name'} = 'dcm2bids_'.$proj;
$ptask{'time'} = '2:0:0';
$ptask{'partition'} = 'fast';
foreach my $subject (sort keys %guys) {
	if ( -d $std{'PET'}.'/'.$guys{$subject} ){
		$ptask{'command'} = 'dcm2bids -d '.$std{'PET'}.'/'.$guys{$subject}.'/ -p '.$subject.' -c '.$std{'DATA'}.'/'.$cfile.' -o '.$std{'DATA'}.'/bids/ --forceDcm2niix';
		$ptask{'filename'} = $outdir.'/'.$subject.'dcm2bids.sh';
		$ptask{'output'} = $outdir.'/dcm2bids'.$subject;
		send2slurm(\%ptask);
		print "$ptask{'filename'}\n";
	}
}
my %final;
$final{'filename'} = $outdir.'/dcm2bids_end.sh';
$final{'job_name'} = 'dcm2bids_'.$proj;
$final{'output'} = $outdir.'/dmc2bids_end';
$final{'dependency'} = 'singleton';
send2slurm(\%final);

