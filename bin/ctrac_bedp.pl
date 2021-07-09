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

use File::Find::Rule;
use NEURO4 qw(print_help load_project cut_shit check_subj check_or_make);
use Data::Dump qw(dump);
use File::Remove 'remove';
use File::Basename qw(basename);
use File::Copy::Recursive qw(dircopy);

my $cfile="";

@ARGV = ("-h") unless @ARGV;

while (@ARGV and $ARGV[0] =~ /^-/) {
    $_ = shift;
    last if /^--$/;
    if (/^-cut/) { $cfile = shift; chomp($cfile);}
    if (/^-h$/) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_prep.hlp'; exit;}
}
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/ctrac_prep.hlp'; exit;}
my %std = load_project($study);
my $w_dir = $std{'WORKING'};
my $data_dir = $std{'DATA'};
my $bids_dir = $std{'BIDS'};
my $fsdir = $ENV{'SUBJECTS_DIR'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $outdir = "$std{'DATA'}/slurm";
check_or_make($outdir);

my @subjects = cut_shit($db, $data_dir."/".$cfile);
my $tmp_orders = 'trac_step2.txt';
my $dmrirc = $data_dir.'/dmri.rc';
unless (-e $dmrirc && -r $dmrirc){
	my $subjlist = 'set subjlist = (  ';
	my $dmclist = 'set dcmlist = ( ';
	my $bveclist = 'set bveclist = ( ';
	my $bavllist = 'set bvallist = ( ';

	foreach my $subject (@subjects) {
		my %nifti = check_subj($std{'DATA'},$subject);
		if($nifti{'dwi'}){
			$subjlist.=$study.'_'.$subject.' ';
			$dmclist.=$nifti{'dwi'}.' ';
			(my $bvec = $nifti{'dwi'}) =~ s/nii\.gz$/bvec/;
			(my $bval = $nifti{'dwi'}) =~ s/nii\.gz$/bval/;
			$bveclist.=$bvec.' ';
			$bavllist.=$bval.' ';
		}
	}
	$subjlist.=')';
	$dmclist.=')';
	$bveclist.=')';
	$bavllist.=')';
	open CIF, ">$dmrirc" or die "Couldnt open dmrirc file for writing\n";
	print CIF "$subjlist\n$dmclist\n$bveclist\n$bavllist\n";
	close CIF;
}
my $pre_order = 'trac-all -bedp -c '.$dmrirc.' -jobs '.$tmp_orders;
system($pre_order);
#run pre-bedp first
(my $pre_tmp_orders = $tmp_orders) =~ s/\.txt/\.pre\.txt/;
open CORD, "<$pre_tmp_orders" or die "Could find orders file";
while (<CORD>){
	(my $subj) = /subjects\/$study\_(.*)\/dmri/;
	my $cpath = $fsdir.'/'.$study.'_'.$subj.'/dmri.bedpostX/logs/monitor';
	system('mkdir -p '.$cpath);
	my $orderfile = $outdir.'/'.$subj.'_trac_pre_bedp.sh';
	open ORD, ">$orderfile";
	print ORD '#!/bin/bash'."\n";
	print ORD '#SBATCH -J trac_pre_bedp_'.$study."\n";
	print ORD '#SBATCH --time=8:0:0'."\n";
	print ORD '#SBATCH --mail-type=FAIL,TIME_LIMIT,STAGE_OUT'."\n";
	print ORD '#SBATCH -o '.$outdir.'/trac_prep-%j'."\n";
	print ORD '#SBATCH -c 8'."\n";
	print ORD '#SBATCH --mem-per-cpu=4G'."\n";
	print ORD '#SBATCH -p fast'."\n";
	print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
	print ORD;
	close ORD;
	system("sbatch $orderfile");
}
close CORD;
my $orderfile = $outdir.'/trac_pre_bedp_end.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J trac_pre_bedp_'.$study."\n";
print ORD '#SBATCH --mail-type=END'."\n"; #email cuando termine
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -p fast'."\n";
print ORD '#SBATCH -o '.$outdir.'/trac_pre_bedp_end-%j'."\n";
print ORD ":\n";
close ORD;
my $order = 'sbatch --dependency=singleton '.$orderfile;
my $jobid = `$order`;
$jobid = ( split ' ', $jobid )[ -1 ];
#run bedp now
my $count = 0;
open CORD, "<$tmp_orders" or die "Could find orders file";
while (<CORD>){
	(my $subj) = /subjects\/$study\_(.*)\/dmri/;
	my $orderfile = $outdir.'/'.$subj.'_'.$count.'_trac_bedp.sh';
        open ORD, ">$orderfile";
        print ORD '#!/bin/bash'."\n";
        print ORD '#SBATCH -J trac_bedp_'.$study."\n";
        print ORD '#SBATCH --time=12:0:0'."\n";
        print ORD '#SBATCH --mail-type=FAIL,TIME_LIMIT,STAGE_OUT'."\n";
        print ORD '#SBATCH -o '.$outdir.'/trac_bedp-%j'."\n";
        print ORD '#SBATCH -c 8'."\n";
	print ORD '#SBATCH --mem-per-cpu=4G'."\n";
        print ORD '#SBATCH -p fast'."\n";
        print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
	print ORD 'srun ';
        print ORD;
        close ORD;
        system('sbatch --depend=afterok:'.$jobid.' '.$orderfile);
	$count++;
}
close CORD;
$orderfile = $outdir.'/trac_bedp_end.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J trac_bedp_'.$study."\n";
print ORD '#SBATCH --mail-type=END'."\n"; #email cuando termine
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -p fast'."\n";
print ORD '#SBATCH -o '.$outdir.'/trac_bedp_end-%j'."\n";
print ORD ":\n";
close ORD;
$order = 'sbatch --dependency=singleton '.$orderfile;
$jobid = `$order`;
$jobid = ( split ' ', $jobid )[ -1 ];
#and post.bedp later
(my $post_tmp_orders = $tmp_orders) =~ s/\.txt/\.post\.txt/;
open CORD, "<$post_tmp_orders" or die "Could find orders file";
while (<CORD>){
        (my $subj) = /subjects\/$study\_(.*)\/dmri/;
        my $orderfile = $outdir.'/'.$subj.'_trac_post_bedp.sh';
        open ORD, ">$orderfile";
        print ORD '#!/bin/bash'."\n";
        print ORD '#SBATCH -J trac_post_bedp_'.$study."\n";
        print ORD '#SBATCH --time=12:0:0'."\n";
        print ORD '#SBATCH --mail-type=FAIL,TIME_LIMIT,STAGE_OUT'."\n";
        print ORD '#SBATCH -o '.$outdir.'/trac_post-%j'."\n";
        print ORD '#SBATCH -c 8'."\n";
	print ORD '#SBATCH --mem-per-cpu=4G'."\n";
        print ORD '#SBATCH -p fast'."\n";
        print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
	#s/bedpostx_postproc\.sh/bedpostx_postproc_gpu.sh/; #It doesnt work :-(
        print ORD;
        close ORD;
        system('sbatch --depend=afterok:'.$jobid.' '.$orderfile);
}
close CORD;
$orderfile = $outdir.'/trac_post_bedp_end.sh';
open ORD, ">$orderfile";
print ORD '#!/bin/bash'."\n";
print ORD '#SBATCH -J trac_post_bedp_'.$study."\n";
print ORD '#SBATCH --mail-type=END'."\n"; #email cuando termine
print ORD '#SBATCH --mail-user='."$ENV{'USER'}\n";
print ORD '#SBATCH -p fast'."\n";
print ORD '#SBATCH -o '.$outdir.'/trac_post_bedp_end-%j'."\n";
print ORD ":\n";
close ORD;
$order = 'sbatch --dependency=singleton '.$orderfile;
exec($order);

