#!/usr/bin/perl

# Copyright 2022 O. Sotolongo <asqwerty@gmail.com>

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
package XNATACE;
require Exporter;
use JSON qw(decode_json); 
use File::Temp qw(:mktemp tempdir);
use Data::Dump qw(dump);
our @ISA = qw(Exporter);
our @EXPORT = qw(xconf xget_conf xget_pet xget_session xget_mri xput_rvr xput_report xget_rvr xget_rvr_data xget_subjects xget_pet_reg xget_fs_data xget_pet_data xget_exp_data xget_sbj_id xget_sbj_data xput_sbj_data xget_fs_stats xget_fs_qc xget_fs_allstats xput_res_file xput_res_data xcreate_res xget_res_data xget_dicom xget_sbj_demog);
our @EXPORT_OK = qw(xconf xget_conf xget_pet xget_session xget_mri xput_rvr xput_report xget_rvr xget_rvr_data xget_subjects xget_pet_reg xget_fs_data xget_pet_data xget_exp_data xget_sbj_id xget_sbj_data xput_sbj_data xget_fs_stats xget_fs_qc xget_fs_allstats xput_res_file xput_res_data xcreate_res xget_res_data xget_dicom xget_sbj_demog);
our %EXPORT_TAGS =(all => qw(xconf xget_conf xget_pet xget_session xget_mri xput_rvr xput_report), usual => qw(xconf xget_conf xget_session));

our $VERSION = 0.1;
our $default_config_path = $ENV{'HOME'}.'/.xnatapic/xnat.conf';

=head1 XNATACE

=over

=item xconf

Publish path of xnatapic configuration file

usage: 

	$path = xconf();

=cut 

sub xconf {
	my $rpath = shift;
	$rpath = $default_config_path unless $rpath;
	return $rpath;
}

=item xget_conf

Get the XNAT connection data into a HASH

usage: 

	%xnat_data = xget_conf()

=cut

sub xget_conf {
	# Get the XNAT connection data into a HASH
	# usage %xnat_data = xconf(configuration_file)
	my $dpath = shift; 
	my $xconf_file = xconf($dpath);
	my %xconf;
	open IDF, "<$xconf_file";
	while (<IDF>){
		if (/^#.*/ or /^\s*$/) { next; }
		my ($n, $v) = /(.*)=(.*)/;
	        $xconf{$n} = $v;
	}
	return %xconf;
}

=item xget_session

Create a new JSESSIONID on XNAT. Return the connection data
for the server AND the ID of the created session

usage: 

	xget_session();

=cut

sub xget_session {
	# Create a new JSESSIONID on XNAT
	# usage: xget_session(\%xconf);
	#my %xdata = %{shift()};
	my $dpath = shift;
	my %xdata = xget_conf($dpath);
	my $crd = 'curl -f -u '.$xdata{'USER'}.':'.$xdata{'PASSWORD'}.' -X POST '.$xdata{'HOST'}.'/data/JSESSION 2>/dev/null';
	$xdata{'JSESSION'} = qx/$crd/;
	return %xdata;
}

=item xget_subjects

Get the list of subjects of a project into a HASH. 
El HASH de input, I<%sbjs>, se construye como I<{ XNAT_ID =E<gt> Label }>

usage: 

	%sbjs = xget_subjects(host, jsession, project);

=cut

sub xget_subjects {
	# Get the list of subjects of a project into a HASH
	# usage: %sbjs = xget_subjects(host, jsession, project); 
	# %sbjs se construye como { XNAT_ID => Label }
	my %sbjs;
	my @xdata = @_;
	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].'/data/projects/'.$xdata[2].'/subjects?format=csv&columns=ID,label" 2>/dev/null';
	my @sbj_res = split '\n', qx/$crd/;
	foreach my $sbj_prop (@sbj_res){
		if ($sbj_prop =~ /^XNAT/){
			my ($sid,$slabel) = $sbj_prop =~ /^(XNAT.+),(\S+),(.*)$/;
			$sbjs{$sid}{'label'} = $slabel;
		}
	}
	return %sbjs;
}

=item xget_sbj_id

Get the subject's ID if the subject label inside a project is known.
Sometimes I need to do this and is not difficult to implement

usage:

	$sbj_id = xget(host, jsession, project, subject_label);

=cut

sub xget_sbj_id {
	my @xdata = @_;
	my $crd = 'curl -f -X GET -b "JSESSIONID='.$xdata[1].'" "'.$xdata[0].'/data/projects/'.$xdata[2].'/subjects/'.$xdata[3].'?format=json" 2>/dev/null | jq \'.items[].data_fields.ID\'';
	my $jres = qx/$crd/;
        $jres =~ s/\"//g;
        chomp $jres;
	return $jres;
} 

=item xget_sbj_data

Get the subject's metadata. Not too much interesting but to extract
the subject label.

usage:

	$xdata = xget_sbj_data(host, jsession, subject, field);

=cut

sub xget_sbj_data {
	# usage $xdata = xget_sbj_data(host, jsession, subject, field);
	my @xdata = @_;
	my $crd = 'curl -f -X GET -b "JSESSIONID='.$xdata[1].'" "'.$xdata[0].'/data/subjects/'.$xdata[2].'?format=json" 2>/dev/null | jq \'.items[].data_fields.'.$xdata[3].'\'';
	my $jres = qx/$crd/;
	$jres =~ s/\"//g;
	chomp $jres;
	#my $xfres = decode_json $jres;
	#return $xfres->{items}[0]{data_fields}{$xdata[3]};
	return $jres;
}

=item xput_sbj_data 

Set a parameter for given subject

usage:

	xput_sbj_data(host, jsession, subject, field, value)

This is the same as 
	curl -f -b "JSESSIONID=57B615F6F6AEDC93E604B252772F3043" -X PUT "http://detritus.fundacioace.com:8088/data/subjects/XNAT_S00823?gender=female,dob=1947-06-07"

but is intended to offer a Perl interface to updating subject data

=cut

sub xput_sbj_data {
	my @xdata = @_;
	my @svars = split /,/, $xdata[3];
	my @svals = split /,/, $xdata[4];
	my $qcad = ''; # Esto seguro que con map se puede hacer en una linea pero vamos que asi tampoco esta mal
	for (my $i=0; $i<scalar(@svars); $i++){
		$qcad .= $svars[$i].'='.$svals[$i].'&';
	}
	$qcad =~ s/\&$//;	
	my $crd = 'curl -f -X PUT -b "JSESSIONID='.$xdata[1].'" "'.$xdata[0].'/data/subjects/'.$xdata[2].'?'.$qcad.'" 2>/dev/null';
	my $res = qx/$crd/;
	return $res;
}


=item xget_sbj_demog

Get demographics variable from given subject, if available

usage:

	$xdata = xget_sbj_demog(host, jsession, project, subject, field);

=cut 

sub xget_sbj_demog {
	my @xdata = @_;
	my $crd = 'curl -f -X GET -b "JSESSIONID='.$xdata[1].'" "'.$xdata[0].'/data/subjects/'.$xdata[2].'?format=json&columns=label,dob" 2>/dev/null | jq \'.items[].children[] | select (.field=="demographics")\' | jq \'.items[].data_fields["'.$xdata[3].'"]\'';
        my $jres = qx/$crd/;
	#my $xfres = decode_json $jres;
	# This is the fucking slowest way to do this shit 
	# but the website with XNAT docs is down right now
	#$jres =~ s/^\s*\".*\":\s*\"(.*)\".*/$1/;
	# get dequotified answer :-o FSM Help me!!!!!
	$jres =~ s/"//g;
	chomp $jres;
	return $jres;
}

=item xget_exp_data

Get a data field of an experiment.
The desired field shoud be indicated as input.
By example, if you want the date of the experiment this is 
seeked as 

	my $xdate = xget_exp_data($host, $session_id, $experiment, 'date')

There are some common fields as I<date>, I<label> or I<dcmPatientId> 
but in general  you should look at,

	curl -X GET -b JSESSIONID=00000blahblah "http://myhost/data/experiments/myexperiment?format=json" 2>/dev/null | jq '.items[0].data_fields'

in order to know the available fields

usage:

	$xdata = xget_exp_data(host, jsession, experiment, field);

=cut

sub xget_exp_data {
	# usage $xdata = xget_exp_data(host, jsession, experiment, field);	
	my @xdata = @_;
	my $crd = 'curl -f -X GET -b "JSESSIONID='.$xdata[1].'" "'.$xdata[0].'/data/experiments/'.$xdata[2].'?format=json" 2>/dev/null | jq \'.items[].data_fields.'.$xdata[3].'\'';
	my $jres = qx/$crd/;
	#my $xfres = decode_json $jres;
	#return $xfres->{items}[0]{data_fields}{$xdata[3]};
	$jres =~ s/\"//g;
	chomp $jres;
	return $jres;
}

=item xget_mri

Get the XNAT MRI experiment ID

usage: 

	xget_mri(host, jsession, project, subject)

=cut

sub xget_mri {
	# Get the XNAT MRI experiment ID
	# usage: xget_mri(host, jsession, project, subject)
	my @xdata = @_;
	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].'/data/projects/'.$xdata[2].'/subjects/'.$xdata[3].'/experiments?format=json&xsiType=xnat:mrSessionData" 2>/dev/null';
	my $json_res = qx/$crd/;
	my $exp_prop = decode_json $json_res;
	my $xlab;
	foreach my $experiment (@{$exp_prop->{'ResultSet'}{'Result'}}){
		$xlab = $experiment->{'ID'};
	}
	return $xlab;
}

=item xget_fs_data

Get the full Freesurfer directory in a tar.gz file

usage: 

	xget_fs_data(host, jsession, project, experiment, output_path)
	
=cut

sub xget_fs_data {
	my @xdata = @_;
	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].'/data/projects/'.$xdata[2].'/experiments/'.$xdata[3].'/resources/FS/files?format=json"  2>/dev/null';
	my $json_res = qx/$crd/;
	my $file_uri;
	my $fs_data = decode_json $json_res;
	foreach my $var_data (@{$fs_data->{'ResultSet'}{'Result'}}){
		if (${$var_data}{'file_content'} eq 'FSresults'){
			$file_uri = ${$var_data}{'URI'};
		}
	}
	if($file_uri){
		$crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].$file_uri.'" -o '.$xdata[4].' 2>/dev/null';
		system($crd);
		return 1;
	}else{
		return 0;
	}
}

=item xget_fs_stats

Get a single stats file from Freesurfer segmentation

usage:

	xget_fs_stats(host, jsession, experiment, stats_file, output_file) 

=cut

sub xget_fs_stats {
	my @xdata = @_;
	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].'/data/experiments/'.$xdata[2].'/resources/FS/files?format=json" 2>/dev/null';
	my $json_res = qx/$crd/;
	my $fs_data = decode_json $json_res;
	my $file_uri;
	foreach my $var_data (@{$fs_data->{'ResultSet'}{'Result'}}){
		if ((${$var_data}{'file_content'} eq 'FSstats') and (${$var_data}{'Name'} eq $xdata[3])){
			$file_uri = ${$var_data}{'URI'};
		}
	}
	if($file_uri){
                $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].$file_uri.'" -o '.$xdata[4].' 2>/dev/null';
		system($crd);
		return 1;
	}else{
		return 0;
	}
}

=item xget_fs_allstats

Get all stats files from Freesurfer segmentation and write it down at selected directory

usage:

        xget_fs_allstats(host, jsession, experiment, output_dir)

=cut

sub xget_fs_allstats {
	my @xdata = @_;
	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].'/data/experiments/'.$xdata[2].'/resources/FS/files?format=json" 2>/dev/null';
	my $json_res = qx/$crd/;
	my $fs_data = decode_json $json_res;
	foreach my $var_data (@{$fs_data->{'ResultSet'}{'Result'}}){
		if ((${$var_data}{'file_content'} eq 'FSstats') and (${$var_data}{'Name'} =~ /.*\.stats$/)){
			$crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].${$var_data}{'URI'}.'" -o '.$xdata[3].'/'.${$var_data}{'Name'}.' 2>/dev/null';
			system($crd);
		}
	}
}

=item xget_fs_qc

Get Freeesurfer QC info

usage:

	xget_fs_qc(host, jsession, experiment);

Output is a hash with I<rating> and I<notes>

=cut 

sub xget_fs_qc {
	my @xdata = @_;
	my %qc;
	my %empty = ('rating' => 0);
	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].'/data/experiments/'.$xdata[2].'/resources/fsqc/files/rating.json" 2>/dev/null';
	my $json_res = qx/$crd/;
	return %empty unless $json_res;
	my $qc_data = decode_json $json_res;
	foreach my $var_data (@{$qc_data->{'ResultSet'}{'Result'}}){
		foreach my $kdata (sort keys %{$var_data}){
			$qc{$kdata} = ${$var_data}{$kdata};
		}
	}
	return %qc;
}

=item xget_pet

Get the XNAT PET experiment ID

usage: 

	xget_pet(host, jsession, project, subject)

=cut

sub xget_pet {
	# Get the XNAT PET experiment ID
	# usage: xget_pet(host, jsession, project, subject)
	my @xdata = @_;
	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].'/data/projects/'.$xdata[2].'/subjects/'.$xdata[3].'/experiments?format=json&xsiType=xnat:petSessionData" 2>/dev/null';
	#print "$crd\n";
	my $json_res = qx/$crd/;
	my $exp_prop = decode_json $json_res;
	my $xlab;
	foreach my $experiment (@{$exp_prop->{'ResultSet'}{'Result'}}){
		$xlab = $experiment->{'ID'};
	}
	return $xlab;
}

=item xget_pet_reg

Download de pet registered into native space in nifti format

usage: 

	xget_pet_reg(host, jsession, experiment, nifti_output);

=cut

sub xget_pet_reg {
	# Download de pet registered into native space in nifti format
	# usage: xget_pet_reg(host, jsession, experiment, nifti_output);
	#
	my @xdata = @_;
	my $crd = 'curl -f -X GET -b "JSESSIONID='.$xdata[1].'" "'.$xdata[0].'/data/experiments/'.$xdata[2].'/files?format=json" 2>/dev/null';
	my $jres = qx/$crd/;
	my $xfres = decode_json $jres;
	foreach my $xres (@{$xfres->{'ResultSet'}{'Result'}}){
		if ($xres->{'file_content'} eq 'PET_reg'){
			my $xuri = $xres->{'URI'};
			my $grd = 'curl -f -b "JSESSIONID='.$xdata[1].'" -X GET "'.$xdata[0].$xuri.'" -o '.$xdata[3].' 2>/dev/null';
			system($grd);
		}
	}
	if (-e $xdata[3]){
		return 1;
	}else{
		return 0;
	}
}

=item xget_pet_data

Get the PET FBB analysis results into a HASH

usage:

	%xresult = xget_pet_data(host, jsession, experiment);

=cut

sub xget_pet_data {
	# Get the PET FBB analysis results into a HASH
	# usage %xresult = xget_pet_reg(host, jsession, experiment);
	my @xdata = @_;
	my %xresult;
	my $crd = 'curl -f -X GET -b "JSESSIONID='.$xdata[1].'" "'.$xdata[0].'/data/experiments/'.$xdata[2].'/files/mriSessionMatch.json" 2>/dev/null';
	my $jres = qx/$crd/;
	if($jres) {
		my $xfres = decode_json $jres;
		foreach my $xres (@{$xfres->{'ResultSet'}{'Result'}}){
			foreach my $xkey (sort keys %{$xres}){
				$xresult{$xkey} = ${$xres}{$xkey};
			}
		}
	}
	return %xresult;
}

=item xput_report

Upload a pdf report to XNAT

usage: 

	xput_report(host, jsession, subject, experiment, pdf_file);

=cut

sub xput_report{
	# upload a pdf report to XNAT
	# usage: xput_report(host, jsession, subject, experiment, pdf_file);
	my @xdata = @_;
	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X PUT "'.$xdata[0].'/data/experiments/'.$xdata[3].'/resources/RVR" 2>/dev/null';
	system($crd);
	$crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X PUT "'.$xdata[0].'/data/experiments/'.$xdata[3].'/resources/RVR/files/report_'.$xdata[2].'.pdf?overwrite=true" -F file="@'.$xdata[4].'"';
       system($crd);       
}

=item xput_rvr

Upload a JSON file with VR data

usage: 

	xput_rvr(host, jsession, experiment, json_file);

=cut

sub xput_rvr {
	# Upload a JSON file with VR data
	# usage: xput_rvr(host, jsession, experiment, json_file);
	my @xdata = @_;
	my $crd = 'curl -f -X PUT -b JSESSIONID='.$xdata[1].' "'.$xdata[0].'/data/experiments/'.$xdata[2].'/resources/RVR/files/report_data.json?overwrite=true" -F file="@'.$xdata[3].'"';
	system($crd);
}

=item xcreate_res 

Create an empty experiment resource

usage:

	xcreate_res(host, jsession, experiment, res_name)

=cut

sub xcreate_res {
	my @xdata = @_;
	my $crd = 'curl -f -X PUT -b JSESSIONID='.$xdata[1].' "'.$xdata[0].'/data/experiments/'.$xdata[2].'/resources/'.$xdata[3].'" 2>/dev/null';
	system($crd);
}

=item xput_res_file

Upload file to an experiment resource

usage:

        xput_res(host, jsession, experiment, type, file, filename)

=cut

sub xput_res_file {
	my @xdata = @_;
	my $crd = 'curl -f -X PUT -b JSESSIONID='.$xdata[1].' "'.$xdata[0].'/data/experiments/'.$xdata[2].'/resources/'.$xdata[3].'/files/'.$xdata[4].'?overwrite=true" -F file="@'.$xdata[5].'"';
	system($crd);
}

=item xput_res_data 

Upload hash to an experiment resource as a json file

usage:

	xput_res_data(host, jsession, experiment, type, file, hash_ref)

=cut

sub xput_res_data {
	my @xdata = @_;
	# El hash se pasa como referencia en ultimo lugar
	my %jdata = %{$xdata[5]};
	# pongo el contenido del hash en un json. Ojo que estoy siguiendo el estilo de XNAT 
	# o seria mucho mas sencillo,
	my $json_content = '{"ResultSet":{"Result":[{';
	my $size = keys %jdata;
	foreach my $jvar (sort keys %jdata){
		$json_content .= '"'.$jvar.'":"'.$jdata{$jvar}.'"';
		$size--;
		$json_content .= ',' if $size;
	}
	$json_content .= '}]}}';
	#ahora tengo que hacer un file para pasarlo con curl
	my $tmp_dir = tempdir(TEMPLATE => $ENV{TMPDIR}.'/wmh_data.XXXXX', CLEANUP => 1);
	my $tmp_file = $tmp_dir.'/'.$xdata[2].'.json';
	open TDF, ">$tmp_file";
	print TDF $json_content;
	close TDF;
	# y a asubir
	my $crd = 'curl -f -X PUT -b JSESSIONID='.$xdata[1].' "'.$xdata[0].'/data/experiments/'.$xdata[2].'/resources/'.$xdata[3].'/files/'.$xdata[4].'?overwrite=true" -F file="@'.$tmp_file.'"';
	system($crd);
}

=item xget_res_data

Dowload data from experiment resource given type and json name

usage:

        xget_res_data(host, jsession, experiment, type, filename)

=cut

sub xget_res_data {
        my @xdata = @_;
        my $crd = 'curl -f -X GET -b JSESSIONID='.$xdata[1].' "'.$xdata[0].'/data/experiments/'.$xdata[2].'/resources/'.$xdata[3].'/files/'.$xdata[4].'" 2>/dev/null';
	my $json_res = qx/$crd/;
	my %out_data;
	if ($json_res) {
		my $data_prop = decode_json $json_res;
		foreach my $data_res (@{$data_prop->{'ResultSet'}{'Result'}}){
			foreach my $kdata (sort keys %{$data_res}){
               			$out_data{$kdata} = ${$data_res}{$kdata};
                	}
		}
	}
	return %out_data;
}


=item xget_rvr

Get VR results into a HASH. Output is a hash with filenames and URI of each element stored at RVR

usage: 

	xget_rvr(host, jsession, project, experiment);

=cut

sub xget_rvr {
	# Get the list of VR results into a HASH
	# usage: xget_rvr(host, jsession, project, experiment);
	# output is a hash with filenames and URI of each element stored at RVR
	my @xdata = @_;
	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].'/data/projects/'.$xdata[2].'/experiments/'.$xdata[3].'/resources/RVR/files?format=json" 2>/dev/null';
	my $json_res = qx/$crd/;
	my $rvr_prop = decode_json $json_res;
	my %report_data;
	foreach my $rvr_res (@{$rvr_prop->{'ResultSet'}{'Result'}}){
		if ($rvr_res->{'Name'}){
			$report_data{$rvr_res->{'Name'}} = $rvr_res->{'URI'};
		}
	}
	return %report_data;
}

=item xget_rvr_data

Get RVR JSON data into a hash

usage: 

	xget_rvr_data(host, jsession, URI);

=cut

sub xget_rvr_data {
	# Get single RVR JSON data into a hash
	# usage: xget_rvr_data(host, jsession, URI);  
	my @xdata = @_;
	my %rvr_data;
	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].$xdata[2].'" 2>/dev/null';
	my $json_res = qx/$crd/;
	my $report_data = decode_json $json_res;
	foreach my $var_data (@{$report_data->{'ResultSet'}{'Result'}}){
		foreach my $kdata (sort keys %{$var_data}){
			$rvr_data{$kdata} = ${$var_data}{$kdata};
		}
	}
	return %rvr_data;
}

=item xget_dicom

Get the full DICOM for a given experiment

usage:

	xget_dicom(host, jsession, experiment, output_dir)

=cut 
	
sub xget_dicom {
	# Get the DICOM!!!!!
	# Only usefull if you want to pass from xnat to acenip
	my @xdata = @_;
	my $tmp_dir = $ENV{'TMPDIR'};
	my $zdir = tempdir(TEMPLATE => ($tmp_dir?$tmp_dir:'.').'/zipdir.XXXXX', CLEANUP => 1);
	my $zipfile = $zdir.'/'.$xdata[2].'.zip';
	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].'/data/experiments/'.$xdata[2].'/scans/ALL/files?format=zip" -o '.$zipfile;
	system($crd);
	my $zrd = '7za x -o'.$xdata[3].' '.$zipfile;
	system($zrd);
}
=back
