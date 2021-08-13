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
use NEURO4 qw(load_project print_help);

my $proj = shift;
die "Should supply project name\n" unless $proj;
my %std = load_project($proj);
my $src_dir = $std{'SRC'};
my $ids_file = $std{'DATA'}.'/ids.csv'; # Este es solo para funcionamiento interno
my $proj_file = $std{'DATA'}.'/'.$proj.'_mri.csv';

#Leo los que han subido 
my @orig_str = qx/ls $src_dir/;
chomp @orig_str;

#Leo el DB previo
my %idsinfo;
my $idscount;
#Pero solo si existe!
if (-e $ids_file){
	open IDS, "<$ids_file" or die $!;
	while(<IDS>){
        	chomp;
	        my ($key, $value) = split(/,\s?/);
        	$idsinfo{$key} = $value;
		$idscount = $value;
	}
	$idscount++;
	close IDS;
}else{
	$idscount++;
}
my @not_in_db = grep !$idsinfo{$_}, @orig_str;
foreach my $guy (@not_in_db) {
        $idsinfo{$guy} = $idscount;
        $idscount++;
}
#Update para todo
open IDS, ">$ids_file" or die $!;
open PDS, ">$proj_file" or die $!;
foreach my $guy (sort {$idsinfo{$a} <=> $idsinfo{$b}} keys %idsinfo) {
        print IDS $guy,",",$idsinfo{$guy},"\n";
        printf PDS "%04d;%s\n", $idsinfo{$guy}, $guy;
}
close PDS;
close IDS;


