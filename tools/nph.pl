#!/usr/bin/perl
#
use strict; 
use warnings;
use NEURO4 qw(print_help load_project cut_shit);
use File::Temp qw( :mktemp tempdir);
use List::Util qw(max sum);
use Data::Dump qw(dump);
my $up_threshold = 0.004;
my $nbins = 100;
my $cfile = "";
sub trim_spaces { return map { s/\s+//gr } @_ }

while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-cut/) { $cfile = shift; chomp($cfile);}
}
my $study = shift;
unless ($study) { print_help $ENV{'PIPEDIR'}.'/doc/dti_metrics.hlp'; exit;}
my %std = load_project($study);
my $w_dir=$std{'WORKING'};
my $data_dir=$std{'DATA'};
my $db = $std{'DATA'}.'/'.$study.'_mri.csv';
my $fsdir = $ENV{'SUBJECTS_DIR'};
my @dtis = cut_shit($db, $data_dir."/".$cfile);
my %nph;
my @allsums;
my $ofile = $data_dir.'/'.$study.'_normalised_peak_height.csv';
foreach my $subject (@dtis){
	my $dti_md = $w_dir.'/'.$subject.'_dti_MD.nii.gz';
	if($subject and -e $dti_md){
		my $tmp_dir = $w_dir.'/.tmp_'.$subject;
		unless (-d $tmp_dir) { mkdir $tmp_dir; }; 
		my $order = 'get_wm_mask.sh '.$study.'_'.$subject.' '.$tmp_dir;
		system($order);
		my $wm_mask_indti = $w_dir.'/'.$subject.'_wm_mask.nii.gz'; 
		my $wm_mask_pre = $w_dir.'/'.$subject.'_wm_tmp.nii.gz';
		$order = 'antsApplyTransforms -d 3 -i '.$tmp_dir.'/wm_mask.nii.gz -r '.$tmp_dir.'/hifi_b0.nii.gz -t '.$tmp_dir.'/'.$subject.'_epi_reg_ANTS.mat -n GenericLabel -o '.$wm_mask_indti;
		#.'; '.$ENV{'FSLDIR'}.'/bin/fslmaths '.$wm_mask_pre.' -thr 0.5 '.$wm_mask_indti;
		system($order);
		my $dti_md_masked = $w_dir.'/'.$subject.'_dti_MD_masked.nii.gz';	
		$order = $ENV{'FSLDIR'}.'/bin/fslmaths '.$dti_md.' -mas '.$wm_mask_indti.' '.$dti_md_masked;
	       	system($order);	
		$order = $ENV{'FSLDIR'}.'/bin/fslstats '.$dti_md_masked.' -l 0 -u '.$up_threshold.' -h '.$nbins;
		my @shist = qx/$order/;
		chomp @shist;
		@shist = trim_spaces(@shist);
		@shist = grep {defined() and length()} @shist;
		#dump @shist;
		$order = $ENV{'FSLDIR'}.'/bin/fslstats '.$dti_md_masked.' -V';
		my $oout =  qx/$order/;
		my @gout = split ' ', $oout;
		my $norm = $gout[0];
		#print "$subject -> $norm\n";
		$nph{$subject}{'sum'} = sum(@shist);
		$nph{$subject}{'norm'} = $norm;
		$nph{$subject}{'max'} = max(@shist);
	}
}
#my $norm = sum(@allsums)/scalar(@allsums);
open ODF, ">$ofile";
print ODF "Subject,NPH\n";
foreach my $subject (sort keys %nph){
	my $nphv = $nph{$subject}{'max'}/$nph{$subject}{'norm'};
	print ODF "$subject,$nphv\n";
}
close ODF;
