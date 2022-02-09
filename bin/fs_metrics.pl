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
use NEURO4 qw(get_subjects check_fs_subj load_project print_help shit_done check_or_make);
use FSMetrics qw(fs_file_metrics);
use File::Basename qw(basename);

# print help if called without arguments
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/fs_metrics.hlp'; exit;}
}

my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/fs_metrics.hlp'; exit;}
my %std = load_project($study);
my $db = $std{DATA}.'/'.$study.'_mri.csv';
my $fsout = $std{DATA}.'/fsrecon';
check_or_make($fsout);
my @plist = get_subjects($db);
my $subj_dir = $ENV{'SUBJECTS_DIR'};
my %stats = fs_file_metrics();

my @fspnames;
foreach my $pkey (@plist){
	my $subj = $study."_".$pkey;
	if(check_fs_subj($subj)){
		push @fspnames, $subj;
	}
}
my $fslist = join ' ', @fspnames;
foreach my $stat (sort keys %stats) {
	if(exists($stats{$stat}{'active'}) && $stats{$stat}{'active'}){
		(my $order = $stats{$stat}{'order'}) =~ s/<list>/$fslist/;
		 $order =~ s/<fs_output>/$fsout/;
		system("$order");
		(my $opatt = $stat) =~ s/_/./g;
		$opatt =~ s/(.*)\.rh$/rh\.$1/;
		$opatt =~ s/(.*)\.lh$/lh\.$1/;
		$order = 'sed \'s/\t/,/g; s/'.$study.'_//;s/^Measure:volume\|^'.$opatt.'/Subject/\' '.$fsout.'/'.$stat.'.txt > '.$fsout.'/'.$stat.'.csv'."\n";
		system($order);
	}
}

my $zfile=$std{DATA}."/".$study."_mri_results.tgz";
system("tar czf $zfile $fsout");
shit_done basename($ENV{_}), $study, $zfile;

