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

# Main idea here is to get WMH stored values as XNAT resources
#
use strict; use warnings;
use NEURO4 qw(load_project trim);
use XNATACE qw(xget_session xget_mri xget_subjects xget_res_data xget_sbj_data xget_exp_data);
use Data::Dump qw(dump);
use File::Temp qw(:mktemp tempdir);
my $prj;
my $xprj;
my $ofile;
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
        $_ = shift;
        last if /^--$/;
        if (/^-o/) { $ofile = shift; chomp($ofile);}
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
my $tmp_dir = $ENV{TMPDIR};
#my %xconf = xget_session();
my %wmhs;
my %subjects = xget_subjects($xprj);
open STDOUT, ">$ofile" unless not $ofile;
print "Subject_ID,Date,WMH\n";
foreach my $sbj (sort keys %subjects){
	my @experiments = xget_mri($xprj, $sbj);
	my $label = xget_sbj_data($sbj, 'label');
	foreach my $experiment (@experiments){
		my %wmh_data = xget_res_data($experiment, 'WMH', 'wmh.json');
		my $date = xget_exp_data($experiment, 'date');
		if (exists($wmh_data{'WMH mm3'}) and $wmh_data{'WMH mm3'}){
			print "$label,$date,$wmh_data{'WMH mm3'}\n";
		}else{
			print "$label,$date,NA\n";
		}
	}
}
close STDOUT;
#dump %wmhs;
