#!/usr/bin/perl
#
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
package FSMetrics;
require Exporter;
our @ISA                = qw(Exporter);
our @EXPORT             = qw(fs_file_metrics fs_fbb_rois tau_rois pet_rois);
our @EXPORT_OK  = qw(fs_file_metrics fs_fbb_rois tau_rois pet_rois);
our %EXPORT_TAGS        = (all => [qw(fs_file_metrics fs_fbb_rois tau_rois pet_rois)], usual => [qw(fs_file_metrics fs_fbb_rois)],);
our $VERSION    = 0.1;

=head1 FSMetrics

Bunch of helpers for storing ROI structure and relative data

=over 

=item fs_file_metrics

This function does not read any input. It sole purpose is to
returns a HASH containing the templates of order for converting Freesurfer (FS)
results into tables.

Any hash element is composed by the template ('order'), a boolean ('active') to decide 
if the FS stats will be processed and the name of the FS stat file ('file'). 
The order template has two wildcards (<list> and <fs_output>) that should be 
parsed and changed by the FS subject id and the output directory where the
data tables will be stored for each subject

The function could be invoked as,

	my %stats = fs_file_metrics();

in any script where this information would be needed. 

The boolean element could be used to choose the stats that should 
be processed and can be added or modified even at run time if needed. The 
stored booleans only provided a decent default

=cut

sub fs_file_metrics {
my %stats = ('wmparc_stats' => {
                'order' => "asegstats2table --subjects <list> --meas volume --skip --statsfile wmparc.stats --all-segs --tablefile <fs_output>/wmparc_stats.txt",
                'active' => 1,
		'file' => 'wmparc_stats.txt',
        },
        'aseg_stats' => {
                'order' => "asegstats2table --subjects <list> --meas volume --skip --tablefile <fs_output>/aseg_stats.txt",
                'active' => 1,
		'file' => 'aseg_stats.txt',
        },
        'aparc_volume_lh' => {
                'order' => "aparcstats2table --subjects <list> --hemi lh --meas volume --skip --tablefile <fs_output>/aparc_volume_lh.txt",
                'active' => 1,
		'file' => 'aparc_volume_lh.txt',
        },
        'aparc_thickness_lh' => {
                'order' => "aparcstats2table --subjects <list> --hemi lh --meas thickness --skip --tablefile <fs_output>/aparc_thickness_lh.txt",
                'active' => 1,
		'file' => 'aparc_thickness_lh.txt',
        },
        'aparc_area_lh' => {
                'order' => "aparcstats2table --subjects <list> --hemi lh --meas area --skip --tablefile <fs_output>/aparc_area_lh.txt",
                'active' => 1,
		'file' => 'aparc_area_lh.txt',
        },
        'aparc_meancurv_lh' => {
                'order' => "aparcstats2table --subjects <list> --hemi lh --meas meancurv --skip --tablefile <fs_output>/aparc_meancurv_lh.txt",
		'file' => 'aparc_meancurv_lh.txt',
        },
        'aparc_volume_rh' => {
                'order' => "aparcstats2table --subjects <list> --hemi rh --meas volume --skip --tablefile <fs_output>/aparc_volume_rh.txt",
                'active' => 1,
		'file' => 'aparc_volume_rh.txt',
        },
        'aparc_thickness_rh' => {
                'order' => "aparcstats2table --subjects <list> --hemi rh --meas thickness --skip --tablefile <fs_output>/aparc_thickness_rh.txt",
                'active' => 1,
		'file' => 'aparc_thickness_rh.txt',
        },
        'aparc_area_rh' => {
                'order' => "aparcstats2table --subjects <list> --hemi rh --meas area --skip --tablefile <fs_output>/aparc_area_rh.txt",
                'active' => 1,
		'file' => 'aparc_area_rh.txt',
        },
        'aparc_meancurv_rh' => {
                'order' => "aparcstats2table --subjects <list> --hemi rh --meas meancurv --skip --tablefile <fs_output>/aparc_meancurv_rh.txt",
		'file' => 'aparc_meancurv_rh.txt',
        },
        'lh.a2009s.volume' => {
                'order' => "aparcstats2table --hemi lh --subjects <list> --parc aparc.a2009s --meas volume --skip -t <fs_output>/lh.a2009s.volume.txt",
		'file' => 'lh.a2009s.volume.txt',
        },
        'lh.a2009s.thickness' => {
                'order' => "aparcstats2table --hemi lh --subjects <list> --parc aparc.a2009s --meas thickness --skip -t <fs_output>/lh.a2009s.thickness.txt",
		'file' => 'lh.a2009s.thickness.txt',
        },
        'lh.a2009s.area' => {
                'order' => "aparcstats2table --hemi lh --subjects <list> --parc aparc.a2009s --meas area --skip -t <fs_output>/lh.a2009s.area.txt",
		'file' => 'lh.a2009s.area.txt',
        },
        'lh.a2009s.meancurv' => {
                'order' => "aparcstats2table --hemi lh --subjects <list> --parc aparc.a2009s --meas meancurv --skip -t <fs_output>/lh.a2009s.meancurv.txt",
		'file' => 'lh.a2009s.meancurv.txt',
        },
        'rh.a2009s.volume' => {
                'order' => "aparcstats2table --hemi rh --subjects <list> --parc aparc.a2009s --meas volume --skip -t <fs_output>/rh.a2009s.volume.txt",
		'file' => 'rh.a2009s.volume.txt',
        },
        'rh.a2009s.thickness' => {
                'order' => "aparcstats2table --hemi rh --subjects <list> --parc aparc.a2009s --meas thickness --skip -t <fs_output>/rh.a2009s.thickness.txt",
		'file' => 'rh.a2009s.thickness.txt',
        },
        'rh.a2009s.area' => {
                'order' => "aparcstats2table --hemi rh --subjects <list> --parc aparc.a2009s --meas area --skip -t <fs_output>/rh.a2009s.area.txt",
		'file' => 'rh.a2009s.area.txt',
        },
        'rh.a2009s.meancurv' => {
                'order' => "aparcstats2table --hemi rh --subjects <list> --parc aparc.a2009s --meas meancurv --skip -t <fs_output>/rh.a2009s.meancurv.txt",
		'file' => 'rh.a2009s.meancurv.txt',
        },
        'lh.BA.volume' => {
                'order' => "aparcstats2table --hemi lh --subjects <list> --parc BA --meas volume --skip -t <fs_output>/lh.BA.volume.txt",
		'file' => 'lh.BA.volume.txt',
        },
        'lh.BA.thickness' => {
                'order' => "aparcstats2table --hemi lh --subjects <list> --parc BA --meas thickness --skip -t <fs_output>/lh.BA.thickness.txt",
		'file' => 'lh.BA.thickness.txt',
        },
        'lh.BA.area' => {
                'order' => "aparcstats2table --hemi lh --subjects <list> --parc BA --meas area --skip -t <fs_output>/lh.BA.area.txt",
		'file' => 'lh.BA.area.txt',
        },
        'lh.BA.meancurv' => {
                'order' => "aparcstats2table --hemi lh --subjects <list> --parc BA --meas meancurv --skip -t <fs_output>/lh.BA.meancurv.txt",
		'file' => 'lh.BA.meancurv.txt',
        },
        'rh.BA.volume' => {
                'order' => "aparcstats2table --hemi rh --subjects <list> --parc BA --meas volume --skip -t <fs_output>/rh.BA.volume.txt",
		'file' => 'rh.BA.volume.txt',
        },
        'rh.BA.thickness' => {
                'order' => "aparcstats2table --hemi rh --subjects <list> --parc BA --meas thickness --skip -t <fs_output>/rh.BA.thickness.txt",
		'file' => 'rh.BA.thickness.txt',
        },
       'lh.BA.area' => {
                'order' => "aparcstats2table --hemi lh --subjects <list> --parc BA --meas area --skip -t <fs_output>/lh.BA.area.txt",
		'file' => 'lh.BA.area.txt',
        },
        'lh.BA.meancurv' => {
                'order' => "aparcstats2table --hemi lh --subjects <list> --parc BA --meas meancurv --skip -t <fs_output>/lh.BA.meancurv.txt",
		'file' => 'lh.BA.meancurv.txt',
        },
        'rh.BA.volume' => {
                'order' => "aparcstats2table --hemi rh --subjects <list> --parc BA --meas volume --skip -t <fs_output>/rh.BA.volume.txt",
		'file' => 'rh.BA.volume.txt',
        },
        'rh.BA.thickness' => {
                'order' => "aparcstats2table --hemi rh --subjects <list> --parc BA --meas thickness --skip -t <fs_output>/rh.BA.thickness.txt",
		'file' => 'rh.BA.thickness.txt',
        },
        'rh.BA.area' => {
                'order' => "aparcstats2table --hemi rh --subjects <list> --parc BA --meas area --skip -t <fs_output>/rh.BA.area.txt",
		'file' => 'rh.BA.area.txt',
        },
        'rh.BA.meancurv' => {
                'order' => "aparcstats2table --hemi rh --subjects <list> --parc BA --meas meancurv --skip -t <fs_output>/rh.BA.meancurv.txt",
		'file' => 'rh.BA.meancurv.txt',
        },
);
return %stats;
}

=item fs_fbb_rois

I<deprecated>

This function exports a HASH that contains the Freesurfer composition of the 
usual segmentations used for building the SUVR ROI

=cut 

sub fs_fbb_rois{
	my %ROIs = (
        	"Global" => ["caudalmiddlefrontal", "lateralorbitofrontal", "medialorbitofrontal", "parsopercularis", "parsorbitalis", "parstriangularis", "rostralmiddlefrontal", "superiorfrontal", "frontalpole", "caudalanteriorcingulate", "isthmuscingulate", "posteriorcingulate", "rostralanteriorcingulate", "inferiorparietal", "precuneus", "superiorparietal", "supramarginal", "middletemporal", "superiortemporal"],
	        "Frontal" => ["parsopercularis", "parsorbitalis", "parstriangularis", "superiorfrontal", "rostralmiddlefrontal", "caudalmiddlefrontal"],
        	"PPCLP" => ["posteriorcingulate", "superiorparietal", "inferiorparietal", "supramarginal", "precuneus"]
	 );
return %ROIs;
}

=item tau_rois

This function takes a string as input and returns an ARRAY containing
the list of ROIs that should be build and where the SUVR should be calculated 

It is intended to be used for PET-Tau but could be used anywhere

By default a list of Braak areas are returned. If the input string is B<alt>
a grouping of those Braak areas is returned. If the purpose is to build 
a meta_temporal ROI the string B<meta> should be passed as input

The main idea here is read the corresponding file for each ROI, stored at
F<PIPEDIR/lib/tau/> and build each ROI with the FS LUTs store there

=cut 

sub tau_rois{
#	my @ROIs = ("braak_1", "braak_2", "braak_12", "braak_3", "braak_4", "braak_34", "braak_5", "braak_6", "braak_56", "meta_temporal");
	my $choice = shift;
	my @ROIs;
	if( $choice && $choice eq "alt"){
		@ROIs = ("braak_12", "braak_34", "braak_56", "extra");
	}elsif( $choice && $choice eq "meta" ){
		@ROIs = ("meta_temporal", "extra");
	}else{
		@ROIs = ("braak_1", "braak_2", "braak_3", "braak_4", "braak_5", "braak_6", "extra");
	}
return @ROIs;
}

=item pet_rois

This function takes a string as input and returns an ARRAY containing
the list of ROIs that should be build and where the SUVR should be calculated

Input values are B<parietal>, B<frontal>, B<pieces> or B<global> (default)

The main idea here is read the corresponding file for each ROI, stored at
F<PIPEDIR/lib/pet/> and build each ROI with the FS LUTs stored there

=cut

sub pet_rois{
	my $choice = shift;
	my @ROIs;
	if( $choice && $choice eq "parietal"){
		@ROIs = ("parietal");
	}elsif( $choice && $choice eq "frontal" ){
		@ROIs = ("frontal");
	}elsif( $choice && $choice eq "pieces" ){
		@ROIs = ("caudalmiddlefrontal", "lateralorbitofrontal", "medialorbitofrontal", "parsopercularis", "parsorbitalis", "parstriangularis", "rostralmiddlefrontal", "superiorfrontal", "frontalpole", "caudalanteriorcingulate", "isthmuscingulate", "posteriorcingulate", "rostralanteriorcingulate", "inferiorparietal", "precuneus", "superiorparietal", "supramarginal", "middletemporal", "superiortemporal");
	}else{
		@ROIs = ("global");
	}
return @ROIs;
}

=back
