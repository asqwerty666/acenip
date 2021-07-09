#!/usr/bin/perl

# Copyright 2020 O. Sotolongo <asqwerty@gmail.com>

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
use NEURO4 qw(populate get_subjects check_fs_subj load_project print_help check_or_make cut_shit);
use FSMetrics qw(fs_file_metrics);
use File::Basename qw(basename);
use File::Slurp qw(read_file);

my $stats = "all";
my $all = 0;
my $prj_alias = "";
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-a/) { $all = 1;}
    if (/^-s/) { $stats = shift;}
    if (/^-p/) { $prj_alias = shift;}
    if (/^-h/) { print_help $ENV{'PIPEDIR'}.'/doc/xnat_get.hlp'; exit;}
}

my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/xnat_get.hlp'; exit;}
unless ($prj_alias) {$prj_alias = $study;}
my %std = load_project($study);
my $db = $std{DATA}.'/'.$study.'_mri.csv';
my $src_dir = $std{'SRC'};
my $subj_dir = $ENV{'SUBJECTS_DIR'};
#my @subjects = cut_shit($db, $std{DATA}."/".$cfile);
my %subj_alias = populate('^(\d{4});(.*)$', $db);
my @fsnames;
my $fsout = $std{DATA}.'/fsrecon';
mkdir $fsout;
unless($all){
	foreach my $subject (sort keys %subj_alias){
		my $fsubj = 'fake_'.$subject;
		push @fsnames, $fsubj;
		my $order = 'mkdir -p '.$subj_dir.'/fake_'.$subject.'/stats';
		system($order);
		$order = 'find '.$src_dir.'/'.$subj_alias{$subject}.'/ -type f | head -1';
		my $one = qx/$order/;
		chomp($one);
		$order = 'dckey -k "PatientID" '.$one.' 2>&1';
		my $expid = qx/$order/;
		$order = 'xnatapic list_experiments --project_id '.$prj_alias.' --label | grep '.$expid;
		my $xpid =qx/$order/;
		my @xepid = split /,/, $xpid;
		$order = 'xnatapic get_fsresults --experiment_id '.$xepid[0].(($stats eq "all")?' --all-stats':' --stats '.$stats).' '.$subj_dir.'/fake_'.$subject.'/stats';
		print "$order\n";
		system($order);
	}
	my %gstats = fs_file_metrics();
	my $fslist = join ' ', @fsnames;

	foreach my $gstat (sort keys %gstats) {
	        if(exists($gstats{$gstat}{'active'}) && $gstats{$gstat}{'active'}){
	                (my $order = $gstats{$gstat}{'order'}) =~ s/<list>/$fslist/;
	                 $order =~ s/<fs_output>/$fsout/;
			if ( -f $subj_dir.'/'.$gstats{$gstat}{'file'}){
	                	system("$order");
	                	(my $opatt = $gstat) =~ s/_/./g;
	                	$opatt =~ s/(.*)\.rh$/rh\.$1/;
	                	$opatt =~ s/(.*)\.lh$/lh\.$1/;
		                $order = 'sed \'s/\t/,/g; s/'.$study.'_//;s/^Measure:volume\|^'.$opatt.'/Subject/\' '.$fsout.'/'.$gstat.'.txt > '.$fsout.'/'.$gstat.'.csv'."\n";
	        	        system($order);
			}
	       	}
	}
	foreach my $subject (sort keys %subj_alias){
		my $order = 'rm -rf '.$subj_dir.'/fake_'.$subject;
		system($order);
	}
}else{
	foreach my $subject (sort keys %subj_alias){
		my $fsubj = $study.'_'.$subject;
		my $order = 'mkdir -p '.$fsubj;
		system($order);
                $order = 'find '.$src_dir.'/'.$subj_alias{$subject}.'/ -type f | head -1';
                my $one = qx/$order/;
                chomp($one);
                $order = 'dckey -k "PatientID" '.$one.' 2>&1';
                my $expid = qx/$order/;
                $order = 'xnatapic list_experiments --project_id '.$prj_alias.' --label | grep '.$expid;
                my $xpid =qx/$order/;
                my @xepid = split /,/, $xpid;
                $order = 'xnatapic get_fsresults --experiment_id '.$xepid[0].' --all-tgz '.$std{DATA}.'/'.$fsubj;
                print "$order\n";
                system($order);
		$order = 'mkdir '.$subj_dir.'/'.$study.'_'.$subject;
		system($order);
                chomp $xepid[1];
		$order= 'tar xzvf '.$std{DATA}.'/'.$study.'_'.$subject.'/'.$xepid[1].'.tar.gz --strip-components=1 -C '.$subj_dir.'/'.$study.'_'.$subject.' XNAT*';
		#print "$order\n";
                system($order);
	}	
}
