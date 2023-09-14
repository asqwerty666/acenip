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
use File::Path qw(make_path);

our @ISA                = qw(Exporter);
our @EXPORT             = qw(print_help load_project cut_shit);
our @EXPORT_OK  = qw(print_help escape_name trim check_or_make load_project populate get_subjects check_subj check_fs_subj get_list shit_done get_pair cut_shit check_pet centiloid_fbb centiloid_fbp centiloid_flute inplace getLoggingTime);
our %EXPORT_TAGS        = (all => [qw(print_help escape_name trim check_or_make load_project check_subj check_fs_subj get_lut run_dckey dclokey centiloid_fbb populate get_subjects get_list shit_done get_pair cut_shit check_pet centiloid_fbp centiloid_flute inplace getLoggingTime)],
                                        usual => [qw(print_help load_project check_or_make cut_shit)],);
our $VERSION    = 1.0;

=head1 NEURO4 

This is a set of functions for helping in the pipeline

=over

=item print_help

just print the help

this funtions reads the path of a TXT file and print it at STDOUT

usage: 

	print_help(help_file);

=cut

sub print_help {
	my $hlp = shift;
	open HELP, "<$hlp";
	while(<HELP>){
		print;
	}
	close HELP;
	return;
}

=item escape_name

This function takes a string and remove some especial characters
in order to escape directory names with a lot of strange symbols.

It returns the escaped string

usage: 

	escape_name(string);

=cut

sub escape_name {
	my $name = shift;
	$name=~s/\ /\\\ /g;
	$name=~s/\`/\\\`/g;
	$name=~s/\(/\\\(/g;
	$name=~s/\)/\\\)/g;
	return $name;
}

=item trim

This function takes a string and remove any trailing spaces after and before the text

usage: 

	trim(string);

=cut

sub trim {
	my $string = shift;
	$string =~ s/^\s+//;  #trim leading space
	$string =~ s/\s+$//;  #trim trailing space
	return $string;
}

=item check_or_make

This is mostly helpless, just takes a path,
checks if exists and create it otherwise

usage: 

	check_or_make(path);

=cut

sub check_or_make {
	my $place = shift;
	# I must check if directory exist, else I create it.
	if(opendir(TEST, $place)){
	closedir TEST;
	}else{
		make_path $place;
	}
}
=item inplace

This function takes a path and a file name or two paths
and returns a string with a single path as result of
the concatenation of the first one plus the second one

usage: 

	inplace(path, filename);

=cut 

sub inplace {
        my $place = shift;
        my $thing = shift;
        $thing =~ s/\/$//;
        if( $thing =~ /\// ){
                $thing =~ s/.*\/(.+?)$/$1/;
        }
        return $place.'/'.$thing;
}

=item load_project

This function take the name of a project, reads the configuration file
that is located at ~/.config/neuro/ and return every project configuration
stored as a hash that can be used at the scripts

usage: 

	load_project(project_name);

=cut

sub load_project {
        my $study = shift;
        my %stdenv = map {/(.*) = (.*)/; $1=>$2 } read_file $ENV{HOME}."/.config/neuro/".$study.".cfg";
        return %stdenv;
}

=item check_subj

Here the fun begins

This function takes as input the name of the project and the subject ID
Then it seeks along the BIDS structure for this subject and returns a hash,
containing the MRI proper images. 

It should return a single value, except for the T1w images, where an array 
is returned. This was though this way because mostly a single session is done.
However, the skill to detect more than one MRI was introduced to allow the 
movement correction when ADNI images are analyzed

So, for T1w images the returned hash should be asked as

	@{$nifti{'T1w'}}

but for other kind of image it should asked as

	$nifti{'T2w'}

usage: 

	check_subj(project_path, bids_id);  

=cut 

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

=item check_pet

This function takes as input the name of the project and the subject ID
Then it seeks along the BIDS structure for this subject and returns a hash,
containing the PET proper images.

If also a tracer is given as input, then the returned hash contains the PET-tau
associated to this tracer. This was introduced as part of a project were the subjects 
were analyzed with different radiotracers.

If no tracer is given, it will seek for the FBB PETs. Those PETs are stored as 

	- single: 4x5min
	- combined: 20min

usage: 

	check_pet(project_path, bids_id, $optional_radiotracer);

=cut

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
			@spet = find(file => 'name' => "sub-".$subj."*_".$tracer."*_tau.nii.gz", in =>  $subj_dir);
		}else{
			@spet = find(file => 'name' => "sub-$subj*_tau.nii.gz", in =>  $subj_dir);
		}
                if (@spet && -e $spet[0] && -f $spet[0]){
                        $pet{'tau'} = $spet[0];
                }
	}
	return %pet;
}

=item check_fs_subj

This function checks if the Freesurfer directory of a given subjects exists

usage: 

	check_fs_subj(freesurfer_id) 

=cut

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

=item get_lut

I really don't even remenber what this shit does

=cut

sub get_lut {
        my $ifile = shift;
        my $patt = '\s*(\d{1,8})\s*([A-Z,a-z,\-,\_,\.,0-9]*)\s*.*';
        my %aseg_data = map {/$patt/; $1=>$2} grep {/^$patt/} read_file $ifile;
        return %aseg_data;
}

=item run_dckey

Get the content of a public tag from a DICOM file.

usage: 

	run_dckey(key, dicom)

=cut

sub run_dckey {
        my @props = @_;
        my $order = "dckey -k $props[1] $props[0] 2\>\&1";
        print "$order\n";
        my $dckey = qx/$order/;
        chomp($dckey);
        $dckey =~ s/\s*//g;
        return $dckey;
}

=item dclokey

Get the content of a private tag from a DICOM file.

usage: 

	dclokey(key, dicom)

=cut

sub dclokey {
        my @props = @_;
        my $order = "dcdump $props[1] 2\>\&1 \| grep \"".$props[0]."\"";
        print "$order\n";
        my $line = qx/$order/;
        (my $dckey) = $line =~ /.*VR=<\w{2}>\s*VL=<0x\d{3,4}[a-z]*>\s*<(.*)\s*>/;
        if($dckey){
                $dckey =~ s/\s*//g;
        }
        return $dckey;
}

=item centiloid_fbb

Returns the proper centiloid value for a given SUVR.
Only valid for FBB.

usage: 

	centiloid_fbb(suvr);

=cut

sub centiloid_fbb {
    my $suvr = shift;
    return 153.4*$suvr-154.9;
}


=item centiloid_fbp 

Returns the proper centiloid value for a given SUVR. 
Only valid for Florbetapir. 

usage:         

centiloid_fbp(suvr); 

=cut 

sub centiloid_fbp {     
	my $suvr = shift;     
	return 183*$suvr-177; 
}


=item centiloid_flute 

Returns the proper centiloid value for a given SUVR. 
Only valid for Flutemetanol. 

usage:         

centiloid_flute(suvr); 

=cut 

sub centiloid_flute {     
	my $suvr = shift;     
	return 121.42*$suvr-121.16; 
}


=item populate

Takes a pattern and a filename and stores the content of the file
into a HASH according to the given pattern

usage: 

	populate(pattern, filename); 

=cut

sub populate {
        my $patt = shift;
        my $csv = shift;
        my %pdata = map { /^$patt$/; $1 => $2} grep {/^$patt$/} read_file $csv;
        return %pdata;
}

=item get_subjects

Parse a project database taking only the subjects and storing them into an array.
The database is expected to be build as,

	0000;name 

usage: 

	get_subjects(filename);

=cut

sub get_subjects {
	my $db = shift;
	my @slist = map {/^(\d{4});.*$/; $1} grep { /^\d{4}/ } read_file($db, chomp => 1);
	return @slist;
}

=item get_list

Parse a project database taking only the subjects and storing them into an array.
The databse is expected to be build with a four digits number at the beginning of 
line. Is similar to get_subjects() function but less restrictive

usage: 

	get_list(filename);

=cut

sub get_list {
	my $ifile = shift;
	my @slist = map {/^(\d{4}).*$/; $1} grep { /^\d{4}/ }read_file($ifile, chomp => 1);
	return @slist;
}

=item get_pair

A single file is loaded as input and parse into a HASH. 
The file should be written in the format:
	
	key;value

usage: 

	get_pair(filename);

=cut

sub get_pair {
        my $ifile = shift;
        my %pet_data = map {/(.*);(.*)/; $1=>$2} read_file $ifile;
        return %pet_data;
}

=item shit_done

this function is intended to be used  after a script ends 
and then an email is send to the user 
with the name of the script, the name of the project and th results attached

usage: 

	shit_done(script_name, project_name, attached_file)

=cut

sub shit_done {
        my @adv = @_;
        my $msg = MIME::Lite->new(
                From    => "$ENV{'USER'}\@detritus.fundacioace.com",
                To      => "$ENV{'USER'}",
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

=item cut_shit

This function takes a project database and a file with a list, then
returns the elements that are common to both.
It is intended to be used to restrict the scripts action 
over a few elements. It returns a single array. 

If it is correctly used, first the db is identified with 
I<load_project()> function and then passed through this function
to get the array of subjects to be analyzed. If the file with 
the cutting list do not exist, an array with all the subjects 
is returned.

usage: 

	cut_shit(db, list);

=cut

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

=item getLoggingTime

This function returns a timestamp based string intended to be used 
to make unique filenames 

Stolen from Stackoverflow

usage: 

	getLoggingTime(); 

=cut 

sub getLoggingTime {
	#shit from stackoverflow. whatelse.
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	my $nice_timestamp = sprintf ( "%04d%02d%02d_%02d%02d%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
return $nice_timestamp;
}

=back
