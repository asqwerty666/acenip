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
package NEURO4;
require Exporter;
use File::Slurp qw(read_file);
use File::Find::Rule;
use Data::Dump qw(dump);
use MIME::Lite;
use File::Basename qw(basename);

our @ISA                = qw(Exporter);
our @EXPORT             = qw(print_help load_project cut_shit);
our @EXPORT_OK  = qw(print_help escape_name trim check_or_make load_project populate get_subjects check_subj check_fs_subj get_list shit_done get_pair cut_shit check_pet centiloid_fbb inplace getLoggingTime);
our %EXPORT_TAGS        = (all => [qw(print_help escape_name trim check_or_make load_project check_subj check_fs_subj get_lut run_dckey dclokey centiloid_fbb populate get_subjects get_list shit_done get_pair cut_shit check_pet centiloid_fbb inplace getLoggingTime)],
                                        usual => [qw(print_help load_project check_or_make cut_shit)],);
our $VERSION    = 1.0;

sub print_help {
# just print the help
	my $hlp = shift;
	open HELP, "<$hlp";
	while(<HELP>){
		print;
	}
	close HELP;
	return;
}

sub escape_name {
# in order to escape directory names with a lot of strange symbols
	my $name = shift;
	$name=~s/\ /\\\ /g;
	$name=~s/\`/\\\`/g;
	$name=~s/\(/\\\(/g;
	$name=~s/\)/\\\)/g;
	return $name;
}

sub trim {
	my $string = shift;
	$string =~ s/^\s+//;  #trim leading space
	$string =~ s/\s+$//;  #trim trailing space
	return $string;
}

sub check_or_make {
	my $place = shift;
	# I must check if directory exist, else I create it.
	if(opendir(TEST, $place)){
	closedir TEST;
	}else{
		mkdir $place;
	}
}

sub inplace {
        my $place = shift;
        my $thing = shift;
        $thing =~ s/\/$//;
        if( $thing =~ /\// ){
                $thing =~ s/.*\/(.+?)$/$1/;
        }
        return $place.'/'.$thing;
}

sub load_project {
        my $study = shift;
        my %stdenv = map {/(.*) = (.*)/; $1=>$2 } read_file $ENV{HOME}."/.config/neuro/".$study.".cfg";
        return %stdenv;
}

sub check_subj {
	my $proj_path = shift;
	my $subj = shift;
	my %mri = ('T1w' => 0, 'T2w' => 0, 'dwi' => 0, 'dwi_sbref' => 0);
	my $subj_dir = $proj_path.'/bids/sub-'.$subj.'/anat';
	if( -e $subj_dir && -d $subj_dir){
		my @t1 = find(file => 'name' => "sub-$subj*_T1w.nii.gz", in =>  $subj_dir);
		if (@t1 && -e $t1[0] && -f $t1[0]){
			#$mri{'T1w'} = $t1[0];
			 $mri{'T1w'} = \@t1;
		}
		my @t2 = find(file => 'name' => "sub-$subj*_T2w.nii.gz", in =>  $subj_dir);
                if (@t2 && -e $t2[0] && -f $t2[0]){
                        $mri{'T2w'} = $t2[0];
              	}
	}
	$subj_dir = $proj_path.'/bids/sub-'.$subj.'/dwi';
	if( -e $subj_dir && -d $subj_dir){
		my @dwi_sbref = find(file => 'name' => "sub-$subj*_sbref_dwi.nii.gz", in =>  $subj_dir);
                if (@dwi_sbref && -e $dwi_sbref[0] && -f $dwi_sbref[0]){
                        $mri{'dwi_sbref'} = $dwi_sbref[0];
                }
		my @dwi = find(file => 'name' => "sub-$subj*_dwi.bval", in =>  $subj_dir);
		if (@dwi && -e $dwi[0] && -f $dwi[0]){
			($mri{'dwi'} = $dwi[0]) =~ s/bval$/nii\.gz/;
		}
	}
	$subj_dir = $proj_path.'/bids/sub-'.$subj.'/func';
	if( -e $subj_dir && -d $subj_dir){
		my @func = find(file => 'name' => "sub-$subj*_bold.nii.gz", in =>  $subj_dir);
		foreach my $task (@func){
			if (-e $task && -f $task){
				$mri{'func'} = $task unless $task =~ /.*sbref.*/;
			}
		}
	}
	return %mri;
}

sub check_pet {
        my ($proj_path, $subj, $tracer) = @_;
	my %pet;
	my $subj_dir = $proj_path.'/bids/sub-'.$subj.'/pet';
	#sub-0001_single_fbb.nii.gz
	if( -e $subj_dir && -d $subj_dir){
		my @spet = find(file => 'name' => "sub-$subj*_single_fbb.nii.gz", in =>  $subj_dir);
		if (@spet && -e $spet[0] && -f $spet[0]){
			$pet{'single'} = $spet[0];
		}
		@spet = find(file => 'name' => "sub-$subj*_combined_fbb.nii.gz", in =>  $subj_dir);
		if (@spet && -e $spet[0] && -f $spet[0]){
                        $pet{'combined'} = $spet[0];
                }
		if (defined $tracer){
			@spet = find(file => 'name' => "sub-".$subj."*_".$tracer."_tau.nii.gz", in =>  $subj_dir);
		}else{
			@spet = find(file => 'name' => "sub-$subj*_tau.nii.gz", in =>  $subj_dir);
		}
                if (@spet && -e $spet[0] && -f $spet[0]){
                        $pet{'tau'} = $spet[0];
                }
	}
	return %pet;
}

sub check_fs_subj {
	my $subj = shift;
	my $subj_dir = qx/echo \$SUBJECTS_DIR/;
	chomp($subj_dir);
	my $place = $subj_dir."/".$subj;
	my $ok = 0;
	# I must check if directory exist.
	if( -e $place && -d $place){$ok = 1;}
	return $ok;
}

sub get_lut {
        my $ifile = shift;
        my $patt = '\s*(\d{1,8})\s*([A-Z,a-z,\-,\_,\.,0-9]*)\s*.*';
        my %aseg_data = map {/$patt/; $1=>$2} grep {/^$patt/} read_file $ifile;
        return %aseg_data;
}

sub run_dckey {
        my @props = @_;
        my $order = "dckey -k $props[1] $props[0] 2\>\&1";
        print "$order\n";
        my $dckey = qx/$order/;
        chomp($dckey);
        $dckey =~ s/\s*//g;
        return $dckey;
}

sub dclokey {
        my @props = @_;
        my $order = "dcdump $props[0] 2\>\&1 \| grep \"".$props[1]."\"";
        print "$order\n";
        my $line = qx/$order/;
        (my $dckey) = $line =~ /.*VR=<\w{2}>\s*VL=<0x\d{3,4}[a-z]*>\s*<(.*)\s*>/;
        if($dckey){
                $dckey =~ s/\s*//g;
        }
        return $dckey;
}

sub centiloid_fbb {
    my $suvr = shift;
    return 153.4*$suvr-154.9;
}

sub populate {
        my $patt = shift;
        my $csv = shift;
        my %pdata = map { /^$patt$/; $1 => $2} grep {/^$patt$/} read_file $csv;
        return %pdata;
}

sub get_subjects {
	my $db = shift;
	my @slist = map {/^(\d{4});.*$/; $1} grep { /^\d{4}/ } read_file($db, chomp => 1);
	return @slist;
}

sub get_list {
	my $ifile = shift;
	my @slist = map {/^(\d{4}).*$/; $1} grep { /^\d{4}/ }read_file($ifile, chomp => 1);
	return @slist;
}

sub get_pair {
        my $ifile = shift;
        my %pet_data = map {/(.*);(.*)/; $1=>$2} read_file $ifile;
        return %pet_data;
}

sub shit_done {
        my @adv = @_;
        my $msg = MIME::Lite->new(
                From    => "$ENV{'USER'}\@detritus.fundacioace.com",
                To      => "$ENV{'USER'}\@detritus.fundacioace.com",
                Subject => 'Script terminado',
                Type    => 'multipart/mixed',
        );

        $msg->attach(
                Type     => 'TEXT',
                Data     => "$adv[0] ha terminado en el estudio $adv[1].\n\n",
        );

        $msg->attach(
                Type     => 'application/gzip',
                Path     => $adv[2],
                Filename => basename($adv[2]),
        );

        $msg->send;
}

sub cut_shit {
	my $db = shift;
	my $cfile = shift;
	my @plist = get_subjects($db);
	my @oklist;
	if ($cfile && -e $cfile && -f $cfile){
        	my @cuts = get_list($cfile);
        	foreach my $cut (sort @cuts){
                	if(grep {/$cut/} @plist){
                       		push @oklist, $cut;
                	}
        	}
	}else{
        	@oklist = @plist;
	}
return @oklist;
}

sub getLoggingTime {
	#shit from stackoverflow. whatelse.
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	my $nice_timestamp = sprintf ( "%04d%02d%02d_%02d%02d%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
return $nice_timestamp;
}
