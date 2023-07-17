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

# Main idea here is to storage some external calculated values as XNAT resources
#
use strict; use warnings;
use NEURO4 qw(load_project trim);
use XNATACE qw(xget_session xget_mri xget_subjects xcreate_res xput_res_data xget_exp_data);
use Data::Dump qw(dump);
use File::Temp qw(:mktemp tempdir);
my $prj;
my $xprj;
my $ifile;
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
        $_ = shift;
        last if /^--$/;
        if (/^-i/) { $ifile = shift; chomp($ifile);}
        if (/^-x/) { $xprj = shift; chomp($xprj);} #nombre del proyecto en XNAT
        if (/^-p/) { $prj = shift; chomp($prj);} #nombre local del proyecto
}

# Mira, hay que meter el proyecto de XNAT con alguno de los dos switch
if ($prj and not $xprj) {
        my %pdata = load_project($prj);
        $xprj = $pdata{'XNAME'};
}
# O te vas a tomar por culo
die "Should supply XNAT project name or define it at local project config!\n" unless $xprj;
# tambien el input file porque si no no hago nada
die "No input data file\n" unless $ifile and -f $ifile;
my %nass;
open IDF, "<$ifile";
while (<IDF>){
	if (/.*,\d{4}-\d{2}-\d{2},\d,\d+\.\d+/){
		my ($sbj, $date, $n, $p) = /(.*),(.*),(.*),(.*)/;
		$nass{$sbj}{$date}{'N'} = $n;
		$nass{$sbj}{$date}{'Nprob'} = $p;
	}
}
close IDF;
# Here comes the magic ;-P
my %xconf = xget_session();
foreach my $sbj (sort keys %nass){
	my @experiments = xget_mri($xconf{'HOST'}, $xconf{'JSESSION'}, $xprj, $sbj);
	foreach my $experiment (@experiments){
		my $date = xget_exp_data($xconf{'HOST'}, $xconf{'JSESSION'}, $experiment, 'date');
		if(exists($nass{$sbj}{$date})) {
			my %ass_data = ('N' => $nass{$sbj}{$date}{'N'}, 'Nprob' => $nass{$sbj}{$date}{'Nprob'}, 'Date' => $date);
			xcreate_res($xconf{'HOST'}, $xconf{'JSESSION'}, $experiment, 'data');
			xput_res_data($xconf{'HOST'}, $xconf{'JSESSION'}, $experiment, 'data', 'neuroass.json', \%ass_data);
		}
	}
}
