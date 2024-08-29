#!/usr/bin/perl 

# Copyright 2024 O. Sotolongo <osotolongo@fundacioace.org>
#
# Here we intend to evaluate whether the PET registration 
# is successfully or not
#
# According to the input the script should decide if the 
# evaluation report is built or results are uploaded as 
# custom forms. So, if I give QC results file as input,
# its content is uploade, or the report is built from
# the registration output stored in XNAT
#

use strict;
use warnings;
use Data::Dump qw(dump);
use Cwd qw(cwd);
use NEURO4 qw(load_project);
use XNATACE qw(xget_subjects xget_pet xget_res_file xput_form_data xget_form_data);
my $prj;
my $xprj;
my $ifile;
my $ofile;
my $wdir = cwd;
my $rhtml = $wdir.'/pet_registration.html';
my $rlist = $wdir.'/pet_registration.csv';
my $imgcd = $wdir.'/imgs';
my $form = 'b82444a5-58ca-4778-ba88-0c84e1cfd3bb';
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-i/) { $ifile = shift; chomp($ifile);} #archivo  con los QC. si existe solo se suben los valores
	if (/^-o/) { $ofile = shift; chomp($ofile);}
	if (/^-x/) { $xprj = shift; chomp($xprj);} #nombre del proyecto en XNAT
	if (/^-p/) { $prj = shift; chomp($prj);} #nombre local del proyecto
}
# Mira, hay que meter el proyecto de XNAT con alguno de los dos switch
if ($prj and not $xprj) {
	my %pdata = load_project($prj);
	$xprj = $pdata{'XNAME'};
}
# O te vas a tomar por culo 
die "Should supply XNAT project name or define it at local project config!\n" unless $xprj;
if ($ifile) {
	open IDF, "$ifile" or die "Can not open $ifile\n";
	while (<IDF>){
		my ($pet, $qc) = /(.*),(.*)/;
		my %tmphash = (qcPass => $qc?'true':'false');
		my $shit = xput_form_data($pet, $form, \%tmphash);
	}
	close IDF;
}elsif ($ofile){
	open ODF, ">$ofile" or die "Can not open $ofile\n";
	print ODF "Subject,QCPASS\n";
	my %subjects = xget_subjects($xprj);
	foreach my $xsbj (sort keys %subjects) {
		$subjects{$xsbj}{PET} = [ xget_pet($xprj, $xsbj) ];
		if (exists($subjects{$xsbj}{PET}) and $subjects{$xsbj}{PET}){
			foreach my $pet (@{$subjects{$xsbj}{PET}}){
				my %qc = xget_form_data($pet, $form);
				if (exists($qc{qcPass})){
					print ODF "$subjects{$xsbj}{label},$qc{qcPass}\n";
				}
			}
		}
	}
}else{
	mkdir $imgcd unless -d $imgcd;
	open OHF, ">$rhtml" or die "Can not open file $_\n";
	open ORF, ">$rlist" or die "Can not open file $_\n";
	print OHF "<html><head><title>PET QC report tool</title></head><body>\n";
	print OHF "<table>\n";
	my %subjects = xget_subjects($xprj);
	foreach my $xsbj (sort keys %subjects) {
		$subjects{$xsbj}{PET} = [ xget_pet($xprj, $xsbj) ];
       		if (exists($subjects{$xsbj}{PET}) and $subjects{$xsbj}{PET}){
			foreach my $pet (@{$subjects{$xsbj}{PET}}){
				my $regpet = xget_res_file($pet, 'MRI', $xsbj.'_fbb_mni.gif', $imgcd.'/'.$pet.'_fbb_mni.gif');
				if (-f $imgcd.'/'.$pet.'_fbb_mni.gif'){
					print OHF '<tr><td><img src="imgs/'.$pet.'_fbb_mni.gif"></td><td>'.$pet.'</td></tr>'."\n";
					print ORF "$pet,0\n";
				}
			}
		}
	}
	print OHF "</table></body></html>\n";
	close OHF;
	close ORF;
}

