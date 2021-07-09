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
	(my $tag)= $imask =~ /masks(\d+)\.nii\.gz/;
	$tag += 1;
	my $ord = "fslstats ".$ifile. " -k ".$tdir.'/'.$imask." -M";
	$mean = qx/$ord/;
	chomp $mean;
	print OF "$tag\t$mean\n";
}
close OF;
(my $suvr = $ifile) =~ s/_tau.nii.gz/_suvr.nii.gz/;
my $ord = "fslmaths $ifile -div $mean $suvr";
system($ord);
