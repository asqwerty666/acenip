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

use strict; use warnings;
package XNATACE;
require Exporter;
use JSON qw(decode_json); 
use Data::Dump qw(dump);
our @ISA = qw(Exporter);
our @EXPORT = qw(xconf xget_pet xget_session xget_mri xput_rvr xput_report xget_rvr xget_rvr_data xget_subjects xget_pet_reg);
our @EXPORT_OK = qw(xconf xget_pet xget_session xget_mri xput_rvr xput_report xget_rvr xget_rvr_data xget_subjects xget_pet_reg);
our %EXPORT_TAGS =(all => qw(xconf xget_pet xget_session xget_mri xput_rvr xput_report), usual => qw(xconf xget_session));

our $VERSION = 0.1;

sub xconf {
	# Get the XNAT connection data into a HASH
	# usage %xnat_data = xconf(configuration_file)
	my $xconf_file = shift;
	my %xconf;
	open IDF, "<$xconf_file";
	while (<IDF>){
		if (/^#.*/ or /^\s*$/) { next; }
		my ($n, $v) = /(.*)=(.*)/;
	        $xconf{$n} = $v;
	}
	return %xconf;
}

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

sub xget_session {
	# Create a new JSESSIONID on XNAT
	# usage: xget_session(\%xconf);
	my %xdata = %{shift()};
	my $crd = 'curl -f -u '.$xdata{'USER'}.':'.$xdata{'PASSWORD'}.' -X POST '.$xdata{'HOST'}.'/data/JSESSION 2>/dev/null';
	return qx/$crd/;
}

sub xput_report{
	# upload a pdf report to XNAT
	# usage: xput_report(host, jsession, subject, experiment, pdf_file);
	my @xdata = @_;
	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X PUT "'.$xdata[0].'/data/experiments/'.$xdata[3].'/resources/RVR" 2>/dev/null';
	system($crd);
	$crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X PUT "'.$xdata[0].'/data/experiments/'.$xdata[3].'/resources/RVR/files/report_'.$xdata[2].'.pdf?overwrite=true" -F file="@'.$xdata[4].'"';
       system($crd);       
}

sub xput_rvr {
	# Upload a JSON file with VR data
	# usage: xput_rvr(host, jsession, experiment, json_file);
	my @xdata = @_;
	my $crd = 'curl -f -X PUT -b JSESSIONID='.$xdata[1].' "'.$xdata[0].'/data/experiments/'.$xdata[2].'/resources/RVR/files/report_data.json?overwrite=true" -F file="@'.$xdata[3].'"';
	system($crd);
}

sub xget_rvr {
	# Get VR results into a HASH
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

sub xget_rvr_data {
	# Get RVR JSON data into a hash
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