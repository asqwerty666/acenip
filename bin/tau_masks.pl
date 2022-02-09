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
use strict; use warnings;
use NEURO4 qw(check_pet check_subj load_project print_help check_or_make cut_shit);
use FSMetrics qw(tau_rois);

my $study = shift;
my $subject= shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/tau_reg.hlp'; exit;}
my %std = load_project($study);
my $order;
my @rois = tau_rois();
foreach my $roi (@rois){
	$order = $ENV{'PIPEDIR'}.'/bin/get_troi.sh '.$study.'_'.$subject.' '.$std{'WORKING'}.'/.tmp_'.$subject.' '.$roi;
	system($order);
}
$order = $ENV{'PIPEDIR'}.'/bin/get_tref_ewm.sh '.$study.'_'.$subject.' '.$std{'WORKING'}.'/.tmp_'.$subject;
system($order);
$order = $ENV{'PIPEDIR'}.'/bin/get_tref_cgm.sh '.$study.'_'.$subject.' '.$std{'WORKING'}.'/.tmp_'.$subject;
system($order);
$order = $ENV{'FSLDIR'}.'/bin/fslmerge ';
