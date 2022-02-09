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

# Este script toma las mascaras guardadas en una imagen 4D
# y calcula el uptake en cada una de las regiones. Escribe estos valores
# en un archivo y divide la imagen inicial entre el valor medio
# de la ultima de las mascaras. Se hace asi porque  se supone que
# antes he guardado la region de referencia como la ultima mascara

use strict; use warnings;
use File::Temp qw(tempdir);
use Data::Dump qw(dump);
use NEURO4 qw(print_help);
my $ifile;
my $ofile;
my $mask;

while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-i/) {$ifile = shift; chomp($ifile);}
    if (/^-m/) {$mask = shift; chomp($mask);}
    if (/^-o/) {$ofile = shift; chomp($ofile);}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/petunc.hlp'; exit;}
}
# Primero tomo el 4D con las mascaras y lo separo en archivos 3D
my $tdir = tempdir( CLEANUP => 1);
my $splord = "$ENV{'FSLDIR'}/bin/fslsplit $mask $tdir/masks -t";
system($splord);
opendir my $dir, "$tdir" or die "Cannot find temp dir\n";
my @files = grep !/^\./, readdir $dir;
close $dir;
my $mean;
open OF, ">$ofile" or die "Could not open output file\n";
print OF "REGION\tMEAN\n";
foreach my $imask (@files){
	# Para cada mascara, saco el valor medio en la region
	# y lo escribo a un archivo
	(my $tag)= $imask =~ /masks(\d+)\.nii\.gz/;
	$tag += 1;
	my $ord = "fslstats ".$ifile. " -k ".$tdir.'/'.$imask." -M";
	$mean = qx/$ord/;
	chomp $mean;
	print OF "$tag\t$mean\n";
}
close OF;
# Y divido el PET por el ultimo valor medio (ROR)
(my $suvr = $ifile) =~ s/_pet.nii.gz/_suvr.nii.gz/;
my $ord = "fslmaths $ifile -div $mean $suvr";
system($ord);
