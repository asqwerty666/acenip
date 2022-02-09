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
use NEURO4 qw(check_or_make print_help);

my $study = shift;
my $src_path = shift;
unless ($study && $src_path) { print_help $ENV{'PIPEDIR'}.'/doc/make_proj.hlp'; exit;}
check_or_make("$ENV{HOME}/.config/neuro");
my $data_dir = "$ENV{PIPEDATA}/$study";
check_or_make("$ENV{PIPEDATA}");
check_or_make("$data_dir");
check_or_make($data_dir.'/working');
check_or_make($data_dir.'/bids');
my $cfg_file = $ENV{HOME}."/.config/neuro/".$study.".cfg";
open DF, ">$cfg_file" or die "$!";
print DF "DATA = $data_dir\n";
print DF "SRC = $src_path\n";
print DF "WORKING = $data_dir/working\n";
print DF "BIDS = $data_dir/bids\n";
close DF;

