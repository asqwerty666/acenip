#!/usr/bin/perl

# Copyright 2021 O. Sotolongo <asqwerty@gmail.com>

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
# This script run the partial volumen correction method of MTC
# over a PET image using a supplied set of masks. The masks file
# is a 4D image where the last 3D should be the reference region.
# The outputs are a txt file with mean values for each mask and a SUVR
# PET image

use strict; use warnings;
use File::Temp qw(tempdir);
use Data::Dump qw(dump);
my $ifile;
my $ofile;
my $mask;

while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-i/) {$ifile = shift; chomp($ifile);}
    if (/^-m/) {$mask = shift; chomp($mask);}
    if (/^-o/) {$ofile = shift; chomp($ofile);}
}

my $tdir = tempdir( CLEANUP => 1);
(my $mtc = $ifile) =~ s/_tau.nii.gz/_mtc.nii.gz/;
my $gomtc = 'petpvc -i '.$ifile.' -m '.$mask.' -o '.$mtc.'.nii.gz -p MTC -x 6.0 -y 6.0 -z 6.0';
system($gomtc);
my $splord = "$ENV{'FSLDIR'}/bin/fslsplit $mask $tdir/masks -t";
system($splord);
opendir my $dir, "$tdir" or die "Cannot find temp dir\n";
my @files = grep !/^\./, readdir $dir;
close $dir;
my $mean;
open OF, ">$ofile" or die "Could not open output file\n";
print OF "REGION\tMEAN\n";
foreach my $imask (@files){
	(my $tag)= $imask =~ /masks(\d+)\.nii\.gz/;
	$tag += 1;
	my $ord = "fslstats ".$mtc. " -k ".$tdir.'/'.$imask." -M";
	$mean = qx/$ord/;
	chomp $mean;
	print OF "$tag\t$mean\n";
}
close OF;
(my $suvr = $ifile) =~ s/_tau.nii.gz/_mtc_suvr.nii.gz/;
my $ord = "fslmaths $ifile -div $mean $suvr";
system($ord);
