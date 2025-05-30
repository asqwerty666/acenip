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
use File::Temp qw(tempfile tempdir);
use Data::Dump qw(dump);
our @ISA = qw(Exporter);
our @EXPORT = qw(xget_pet xget_session xget_mri xlist_res xget_subjects xget_pet_reg xget_pet_data xget_exp_data xget_sbj_id xget_sbj_data xput_sbj_data xput_res_file xput_res_data xcreate_res xget_res_data xget_res_file xget_res_file_tr xget_dicom xget_sbj_demog xput_dicom xnew_dicom check_status force_archive xget_mri_pipelines xrun_mri_pipeline xput_form_data xget_form_data);
our @EXPORT_OK = qw(xget_pet xget_session xget_mri xlist_res xget_subjects xget_pet_reg xget_pet_data xget_exp_data xget_sbj_id xget_sbj_data xput_sbj_data xput_res_file xput_res_data xcreate_res xget_res_data xget_res_file xget_dicom xget_sbj_demog xput_dicom xnew_dicom check_status force_archive xget_mri_pipelines xrun_mri_pipeline xput_form_data xget_form_data);
our %EXPORT_TAGS =(all => qw(xget_session xget_pet xget_mri), usual => qw(xget_session));

our $VERSION = 0.2;
our $default_config_path = $ENV{'HOME'}.'/.xnatapic/xnat.conf';
#=item xconf
#
#Publish path of xnatapic configuration file
#
#usage: 
#
#	$path = xconf();
#
#=cut 

sub xconf {
	my $rpath = shift;
	$rpath = $default_config_path unless $rpath;
	return $rpath;
}

#=item xget_conf
#
#Get the XNAT connection data into a HASH
#
#usage: 
#
#	%xnat_data = xget_conf()
#
#=cut

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
		$n =~ s/.*\s//;
	        $xconf{$n} = $v;
	}
	#dump %xconf;
	return %xconf;
}

=head1 XNATACE

=over

=item xget_session

Create a new JSESSIONID on XNAT. Return the connection data
for the server AND the ID of the created session

usage: 

	%conn = xget_session();

=cut

sub xget_session {
	# Create a new JSESSIONID on XNAT
	# usage: xget_session(\%xconf);
	#my %xdata = %{shift()};
	my $dpath = shift;
	my %xdata = xget_conf($dpath);
	my $CACERT = '';
	if (exists($xdata{'CURL_CA_BUNDLE'}) and $xdata{'CURL_CA_BUNDLE'}){
		$CACERT = $xdata{'CURL_CA_BUNDLE'};
	}
	my $crd = 'curl '.($CACERT?'--cacert '.$CACERT:'').' -f -u '.$xdata{'USER'}.':'.$xdata{'PASSWORD'}.' -X POST '.$xdata{'HOST'}.'/data/JSESSION 2>/dev/null';
	$xdata{'JSESSION'} = qx/$crd/;
	die "Could not connect to XNAT!\n" unless $xdata{'JSESSION'};
	#dump %xdata;
	return %xdata;
}

=item xget_subjects

Get the list of subjects of a project into a HASH. 
El HASH de input, I<%sbjs>, se construye como I<{ XNAT_ID =E<gt> Label }>

usage: 

	%sbjs = xget_subjects(project);

=cut

sub xget_subjects {
	# Get the list of subjects of a project into a HASH
	# usage: %sbjs = xget_subjects(host, jsession, project); 
	# %sbjs se construye como { XNAT_ID => Label }
	my %sbjs;
	my %cdata = xget_session();
	my @xdata = @_;
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b JSESSIONID='.$cdata{'JSESSION'}.' -X GET "'.$cdata{'HOST'}.'/data/projects/'.$xdata[0].'/subjects?format=csv&columns=ID,label" 2>/dev/null';
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

	$sbj_id = xget_sbj_id(project, subject_label);

=cut

sub xget_sbj_id {
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X GET -b "JSESSIONID='.$cdata{'JSESSION'}.'" "'.$cdata{'HOST'}.'/data/projects/'.$xdata[0].'/subjects/'.$xdata[1].'?format=json" 2>/dev/null | jq \'.items[].data_fields.ID\'';
	my $jres = qx/$crd/;
        $jres =~ s/\"//g;
        chomp $jres;
	return $jres;
} 

=item xget_sbj_data

Get the subject's metadata. Not too much interesting but to extract
the subject label.

usage:

	$xdata = xget_sbj_data(subject, field);

=cut

sub xget_sbj_data {
	# usage $xdata = xget_sbj_data(subject, field);
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X GET -b "JSESSIONID='.$cdata{'JSESSION'}.'" "'.$cdata{'HOST'}.'/data/subjects/'.$xdata[0].'?format=json" 2>/dev/null | jq \'.items[].data_fields.'.$xdata[1].'\'';
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

	$xdata = xput_sbj_data(subject, field, value)

This is the same as 
	
	curl -f -b "JSESSIONID=57B615F6F6AEDC93E604B252772F3043" -X PUT "http://detritus.fundacioace.com:8088/data/subjects/XNAT_S00823?gender=female,dob=1947-06-07"

but is intended to offer a Perl interface to updating subject data. If everything is OK, it returns the subject ID or nothing if somethign  goes wrong. So you could check your own disaster.

Notice that I<field> could be a comma separated list but you should fill I<value> with the correpondent list.

=cut

sub xput_sbj_data {
	my @xdata = @_;
	my @svars = split /,/, $xdata[1];
	my @svals = split /,/, $xdata[2];
	my %cdata = xget_session();
	my $qcad = ''; # Esto seguro que con map se puede hacer en una linea pero vamos que asi tampoco esta mal
	for (my $i=0; $i<scalar(@svars); $i++){
		$qcad .= $svars[$i].'='.$svals[$i].'&';
	}
	$qcad =~ s/\&$//;	
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X PUT -b "JSESSIONID='.$cdata{'JSESSION'}.'" "'.$cdata{'HOST'}.'/data/subjects/'.$xdata[0].'?'.$qcad.'" 2>/dev/null';
	my $res = qx/$crd/;
	return $res;
}


=item xget_sbj_demog

Get demographics variable from given subject, if available

usage:

	$xdata = xget_sbj_demog(subject, field);

=cut 

sub xget_sbj_demog {
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X GET -b "JSESSIONID='.$cdata{'JSESSION'}.'" "'.$cdata{'HOST'}.'/data/subjects/'.$xdata[0].'?format=json&columns=label,dob" 2>/dev/null | jq \'.items[].children[] | select (.field=="demographics") | .items[].data_fields["'.$xdata[1].'"]\'';
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

	$xdata = xget_exp_data(experiment, field);

=cut

sub xget_exp_data {
	# usage $xdata = xget_exp_data(experiment, field);	
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X GET -b "JSESSIONID='.$cdata{'JSESSION'}.'" "'.$cdata{'HOST'}.'/data/experiments/'.$xdata[0].'?format=json" 2>/dev/null | jq \'.items[].data_fields.'.$xdata[1].'\'';
	my $jres = qx/$crd/;
	#my $xfres = decode_json $jres;
	#return $xfres->{items}[0]{data_fields}{$xdata[1]};
	$jres =~ s/\"//g;
	chomp $jres;
	return $jres;
}

=item xget_mri

Get the XNAT MRI experiment ID

usage: 

	@experiment_IDs = xget_mri(project, subject)

=cut

sub xget_mri {
	# Get the XNAT MRI experiment ID
	# usage: xget_mri(project, subject)
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b JSESSIONID='.$cdata{'JSESSION'}.' -X GET "'.$cdata{'HOST'}.'/data/projects/'.$xdata[0].'/subjects/'.$xdata[1].'/experiments?format=json&xsiType=xnat:mrSessionData" 2>/dev/null';
	my $json_res = qx/$crd/;
	if ($json_res){
		my $exp_prop = decode_json $json_res;
		my @xlab;
		foreach my $experiment (@{$exp_prop->{'ResultSet'}{'Result'}}){
			push @xlab, $experiment->{'ID'};
		}
		return @xlab;
	}else{
		return 0;
	}
}


#=item xget_fs_qc
#
#Get Freeesurfer QC info.
#
#I'm sure this could be deprecated by xget_res_data(), so better do not use it.
#
#usage:
#
#	%fsqc = xget_fs_qc(host, jsession, experiment);
#
#Output is a hash with I<rating> and I<notes>
#
#=cut 
#
#sub xget_fs_qc {
#	my @xdata = @_;
#	my %qc;
#	my %empty = ('rating' => 0);
#	my $crd = 'curl -f -b JSESSIONID='.$xdata[1].' -X GET "'.$xdata[0].'/data/experiments/'.$xdata[2].'/resources/fsqc/files/rating.json" 2>/dev/null';
#	my $json_res = qx/$crd/;
#	return %empty unless $json_res;
#	my $qc_data = decode_json $json_res;
#	foreach my $var_data (@{$qc_data->{'ResultSet'}{'Result'}}){
#		foreach my $kdata (sort keys %{$var_data}){
#			$qc{$kdata} = ${$var_data}{$kdata};
#		}
#	}
#	return %qc;
#}

=item xget_pet

Get the XNAT PET experiment ID

usage: 

	@experiment_ids = xget_pet(project, subject)

Returns experiment ID.

=cut

sub xget_pet {
	# Get the XNAT PET experiment ID
	# usage: xget_pet(project, subject)
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b JSESSIONID='.$cdata{'JSESSION'}.' -X GET "'.$cdata{'HOST'}.'/data/projects/'.$xdata[0].'/subjects/'.$xdata[1].'/experiments?format=json&xsiType=xnat:petSessionData" 2>/dev/null';
	#print "$crd\n";
	my $json_res = qx/$crd/;
	my @xlab;
	if ($json_res){
		my $exp_prop = decode_json $json_res;
		foreach my $experiment (@{$exp_prop->{'ResultSet'}{'Result'}}){
			push @xlab, $experiment->{'ID'};
		}
	}
	return @xlab;
}

=item xget_pet_reg

Download de pet registered into native space in nifti format

usage: 

	$result = xget_pet_reg(experiment, nifti_output);

Returns 1 if OK, 0 otherwise.

=cut

sub xget_pet_reg {
	# Download de pet registered into native space in nifti format
	# usage: xget_pet_reg(experiment, nifti_output);
	#
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X GET -b "JSESSIONID='.$cdata{'JSESSION'}.'" "'.$cdata{'HOST'}.'/data/experiments/'.$xdata[0].'/files?format=json" 2>/dev/null';
	my $jres = qx/$crd/;
	my $xfres = decode_json $jres;
	foreach my $xres (@{$xfres->{'ResultSet'}{'Result'}}){
		if ($xres->{'file_content'} eq 'PET_reg'){
			my $xuri = $xres->{'URI'};
			my $grd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b "JSESSIONID='.$cdata{'JSESSION'}.'" -X GET "'.$cdata{'HOST'}.$xuri.'" -o '.$xdata[1].' 2>/dev/null';
			system($grd);
		}
	}
	if (-e $xdata[1]){
		return 1;
	}else{
		return 0;
	}
}

=item xget_pet_data

Get the PET FBB analysis results into a HASH

usage:

	%xresult = xget_pet_data(experiment);

Returns a hash with the results of the PET analysis

=cut

sub xget_pet_data {
	# Get the PET FBB analysis results into a HASH
	# usage %xresult = xget_pet_reg(experiment);
	my @xdata = @_;
	my %cdata = xget_session();
	my %xresult;
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X GET -b "JSESSIONID='.$cdata{'JSESSION'}.'" "'.$cdata{'HOST'}.'/data/experiments/'.$xdata[0].'/files/mriSessionMatch.json" 2>/dev/null';
	my $jres = qx/$crd/;
	if($jres and $jres =~ '.*ResultSet.*') {
		my $xfres = decode_json $jres;
		foreach my $xres (@{$xfres->{'ResultSet'}{'Result'}}){
			foreach my $xkey (sort keys %{$xres}){
				$xresult{$xkey} = ${$xres}{$xkey};
			}
		}
	}
	return %xresult;
}


=item xcreate_res 

Create an empty experiment resource

usage:

	xcreate_res(experiment, res_name)

=cut

sub xcreate_res {
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X PUT -b JSESSIONID='.$cdata{'JSESSION'}.' "'.$cdata{'HOST'}.'/data/experiments/'.$xdata[0].'/resources/'.$xdata[1].'" 2>/dev/null';
	system($crd);
}

=item xput_res_file

Upload file as experiment resource

usage:

        xput_res(experiment, type, file, filename)

=cut

sub xput_res_file {
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X PUT -b JSESSIONID='.$cdata{'JSESSION'}.' "'.$cdata{'HOST'}.'/data/experiments/'.$xdata[0].'/resources/'.$xdata[1].'/files/'.$xdata[2].'?overwrite=true" -F file="@'.$xdata[3].'"';
	system($crd);
}

=item xput_res_data 

Upload hash to an experiment resource as a json file

usage:

	xput_res_data(experiment, type, file, hash_ref)

=cut

sub xput_res_data {
	my @xdata = @_;
	my %cdata = xget_session();
	# El hash se pasa como referencia en ultimo lugar
	my %jdata = %{$xdata[3]};
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
	my $tmp_dir = tempdir(TEMPLATE => $ENV{TMPDIR}.'/resource_data.XXXXX', CLEANUP => 1);
	my $tmp_file = $tmp_dir.'/'.$xdata[0].'.json';
	open TDF, ">$tmp_file";
	print TDF $json_content;
	close TDF;
	# y a asubir
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X PUT -b JSESSIONID='.$cdata{'JSESSION'}.' "'.$cdata{'HOST'}.'/data/experiments/'.$xdata[0].'/resources/'.$xdata[1].'/files/'.$xdata[2].'?overwrite=true" -F file="@'.$tmp_file.'"';
	system($crd);
}

=item xput_form_data

Upload hash to an experiment custom form 
(should be extend to subjects and projects but I need to think how to do it)

usage:

	xput_form_data(experiment, form_uuid, hash_ref)

=cut

sub xput_form_data {
	my @xdata = @_;
	my %cdata = xget_session();
	my %jdata = %{$xdata[2]};
	my $json_content = '{"'.$xdata[1].'": {';
	my $size = keys %jdata;
	foreach my $jvar (sort keys %jdata){
		$json_content .= '"'.$jvar.'":"'.$jdata{$jvar}.'"';
		$size--;
		$json_content .= ',' if $size;
	}
	$json_content .= '}}';
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X PUT -b JSESSIONID='.$cdata{'JSESSION'}.' "'.$cdata{'HOST'}.'/xapi/custom-fields/experiments/'.$xdata[0].'/fields" -H \'accept: application/json\' -H \'Content-Type: application/json\' -d \''.$json_content.'\' 2>/dev/null';
	return qx/$crd/;

}

=item xget_form_data

Download custom form for an experiment as a hash

usage:

	%xdata = xget_form_data(experiment, form_uuid)

=cut

sub xget_form_data {
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X GET -b JSESSIONID='.$cdata{'JSESSION'}.' "'.$cdata{'HOST'}.'/xapi/custom-fields/experiments/'.$xdata[0].'/fields" 2>/dev/null';
	my $json_res = qx/$crd/;
	my %out_data;
	if ($json_res) {
		my $data_prop = decode_json $json_res;
		foreach my $kdata (sort keys %{$data_prop->{$xdata[1]}}){
			$out_data{$kdata} = ${$data_prop->{$xdata[1]}}{$kdata};
		}
	}
	return %out_data;
}

=item xget_res_data

Download data from experiment resource given type and json name

usage:

        %xdata = xget_res_data(experiment, type, filename)

Returns a hash with the JSON elements

=cut

sub xget_res_data {
        my @xdata = @_;
	my %cdata = xget_session();
        my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X GET -b JSESSIONID='.$cdata{'JSESSION'}.' "'.$cdata{'HOST'}.'/data/experiments/'.$xdata[0].'/resources/'.$xdata[1].'/files/'.$xdata[2].'" 2>/dev/null';
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

=item xget_res_file

Download file from experiment resource

usage:

	$result = xget_res_file(experiment, type, filename, output, just_print)

=cut

sub xget_res_file {
	my @xdata = @_;
	my %cdata = xget_session();
	my $jp = $xdata[4] if defined $xdata[4];
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -X GET -b JSESSIONID='.$cdata{'JSESSION'}.' "'.$cdata{'HOST'}.'/data/experiments/'.$xdata[0].'/resources/'.$xdata[1].'/files/'.$xdata[2].'" -o '.$xdata[3].' 2>/dev/null';
	return $crd if $jp;
	my $res = qx/$crd/;
	return $res;
}


=item xlist_res

Put the resources files into a HASH. 
Output is a hash with filenames and URI of each element stored at the resource.

usage:

	%xdata = xlist_res(experiment, resource); 

=cut


sub xlist_res {
	# Get the list of resources into a HASH
	# usage: xget_list(experiment, resource);
	# output is a hash with filenames and URI of each element stored at RVR
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b "JSESSIONID='.$cdata{'JSESSION'}.'" -X GET "'.$cdata{'HOST'}.'/data/experiments/'.$xdata[0].'/resources/'.$xdata[1].'/files?format=json" 2>/dev/null';
	my $json_res = qx/$crd/;
	my %report_data;
	if ($json_res){
		my $rvr_prop = decode_json $json_res;
		foreach my $rvr_res (@{$rvr_prop->{'ResultSet'}{'Result'}}){
			if ($rvr_res->{'Name'}){
				$report_data{$rvr_res->{'Name'}} = $rvr_res->{'URI'};
			}
		}
	}
	return %report_data;
}

=item xget_dicom

Download DICOM for a given experiment into the desired output directory.

You can download the full experiment or just a list of series enumerated with a comma separated list of I<series_description> tag

usage:

	xget_dicom(experiment, output_dir, series_description)

If I<series_description> is ommited then is assumed equal to 'ALL' and the full DICOM will be downloaded

=cut 
	
sub xget_dicom {
	# Get the DICOM!!!!!
	# Only usefull if you want to go from xnat to acenip
	my @xdata = @_;
	my %cdata = xget_session();
	my $a_size = scalar @xdata;
	push @xdata, 'ALL' unless $a_size > 2;
	my $tmp_dir = $ENV{'TMPDIR'};
	my $zdir = tempdir(TEMPLATE => ($tmp_dir?$tmp_dir:'.').'/zipdir.XXXXX', CLEANUP => 1);
	my $zipfile = $zdir.'/'.$xdata[0].'.zip';
	my $crd; my $all_types = 'ALL';
	unless ($xdata[2] ne 'ALL') {
		$crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b JSESSIONID='.$cdata{'JSESSION'}.' -X GET "'.$cdata{'HOST'}.'/data/experiments/'.$xdata[0].'/scans/ALL/files?format=zip" -o '.$zipfile.' 2>/dev/null';
	}else{
		my @series = split ',', $xdata[2];
		my @types;
		foreach my $serie (@series){
			my $icrd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b JSESSIONID='.$cdata{'JSESSION'}.' -X GET "'.$cdata{'HOST'}.'/data/experiments/'.$xdata[0].'/scans?format=json" 2>/dev/null | jq \'.ResultSet.Result[] | select (.series_description | test("'.$serie.'")) | .ID\'';
			my $ires = qx/$icrd/;
			$ires =~ s/\"//g;
			my @ares = split /\n/, $ires;
			chomp @ares;
			push @types, @ares if @ares;
		}
		$all_types = join ',', @types;
		$crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b JSESSIONID='.$cdata{'JSESSION'}.' -X GET "'.$cdata{'HOST'}.'/data/experiments/'.$xdata[0].'/scans/'.$all_types.'/files?format=zip" -o '.$zipfile.' 2>/dev/null' if $all_types;	
	}
	if ($crd) {
		system($crd);
		my $zrd = '7za x -y -o'.$xdata[1].' '.$zipfile.' 1>/dev/null' ;
		system($zrd);
		unlink $zdir;
	}
	return $all_types;
}


=item xput_dicom

Upload DICOM for a subject

usage:
	
	xput_dicom(project, subject, path)

=cut

sub xput_dicom {
	my @xdata = @_;
	my %cdata = xget_session();
	my $tmp_dir = $ENV{'TMPDIR'};
	my $zdir = tempdir(TEMPLATE => ($tmp_dir?$tmp_dir:'.').'/zipdir.XXXXX', CLEANUP => 1);
	my $tzfile = $zdir.'/'.$xdata[1].'.tar.gz';
	my $crd = 'tar czf '.$tzfile.' '.$xdata[2].' 2>/dev/null';
	system($crd);
	$crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b JSESSIONID='.$cdata{'JSESSION'}.' -X POST "'.$cdata{'HOST'}.'/data/services/import?import-handler=DICOM-zip&Direct-Archive=true&Ignore-Unparsable=true&project='.$xdata[0].'&subject='.$xdata[1].'&overwrite=delete" -F file.tar.gz="@'.$tzfile.'" 2>/dev/null';
	#print "$crd\n";
	return qx/$crd/;
}


=item xnew_dicom

Upload DICOM for and unknown subject

usage:
	
	xnew_dicom(project, path)

=cut

sub xnew_dicom {
	my @xdata = @_;
	my %cdata = xget_session();
	my $tmp_dir = $ENV{'TMPDIR'};
	my ($fh, $tzfile) = tempfile(TEMPLATE => 'tmp_XXXXXXXX', SUFFIX => '.tar.gz', DIR => $tmp_dir);
	my $crd = 'tar czf '.$tzfile.' '.$xdata[1].' 2>/dev/null';
	system($crd);
	$crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b JSESSIONID='.$cdata{'JSESSION'}.' -X POST "'.$cdata{'HOST'}.'/data/services/import?import-handler=DICOM-zip&Direct-Archive=true&Ignore-Unparsable=true&project='.$xdata[0].'&overwrite=delete" -F file.tar.gz="@'.$tzfile.'" 2>/dev/null';
	#print "$crd\n";
	return qx/$crd/;
}


=item check_status

Check the status of the upload

usage:
	
	check_status(path)

=cut

sub check_status {
	my @xdata = @_;
	$xdata[0] =~ s/\r//g;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b JSESSIONID='.$cdata{'JSESSION'}.' -X GET "'.$cdata{'HOST'}.$xdata[0].'" 2>/dev/null | jq ".status"';
	return qx/$crd/;
}

=item xget_mri_pipelines

Get the MRI project pipelines

usage:

	xget_mri_pipelines(project)

=cut

sub xget_mri_pipelines {
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b JSESSIONID='.$cdata{'JSESSION'}.' -X GET "'.$cdata{'HOST'}.'/data/projects/'.$xdata[0].'/pipelines?format=json" 2>/dev/null';
	my $json_res = qx/$crd/;
	if($json_res) {
		my $exp_prop = decode_json $json_res;
		my @xpipe;
		foreach my $pipe (@{$exp_prop->{'ResultSet'}{'Result'}}){
			if( $pipe->{'Datatype'} eq "xnat:mrSessionData"){
				push @xpipe,  $pipe->{'Name'};
			}
		}
		return @xpipe;
	}else{
		return 0;
	}
}


=item xrun_mri_pipeline

Run the MRI project pipeline

usage:

	xrun_mri_pipeline(project, pipeline, experiment, parameters)

=cut

sub xrun_mri_pipeline {
	my @xdata = @_;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b JSESSIONID='.$cdata{'JSESSION'}.' -X POST "'.$cdata{'HOST'}.'/data/projects/'.$xdata[0].'/pipelines/'.$xdata[1].'/experiments/'.$xdata[2].($xdata[3]?'?'.$xdata[3]:'').'" 2>/dev/null';
	return qx/$crd/;
}

=item force_archive

Force the archiving of the uploaded DICOM

usage:
	
	force_archive(path)

=cut

sub force_archive {
	my @xdata = @_;
	$xdata[0] =~ s/\r//g;
	my %cdata = xget_session();
	my $crd = 'curl '.($cdata{'CURL_CA_BUNDLE'}?'--cacert '.$cdata{'CURL_CA_BUNDLE'}:'').' -f -b JSESSIONID='.$cdata{'JSESSION'}.' -X POST "'.$cdata{'HOST'}.$xdata[0].'" 2>/dev/null';
	#	print "$crd\n";
	return qx/$crd/;
}


=item xlist_iassessors

Get list of image assessors

usage:
	
	xlist_iassessors(experiment)

=cut

sub xlist_iassessors{
	my @xdata = @_;
	my %cdata = xget_session();
}


=item xget_iassessor

Get image assessor

usage:
	
	xget_iassessor(experiment, assessor)


=cut 

sub xget_iassessor{
	my @xdata = @_;
	my %cdata = xget_session();
}

=back
