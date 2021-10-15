#!/usr/bin/perl
#
use strict; 
use warnings;
use NEURO4 qw(print_help load_project cut_shit);
use File::Temp qw( :mktemp tempdir);
use List::Util qw(max sum);
my $up_threshold = 0.004;
my $nbins = 100;
my $cfile;
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
my @dtis = cut_shit($db, $data_dir."/".$cfile);
my %nph;
my @allsums;
foreach my $subject (@dtis){
	my $dti_md = $w_dir.'/'.$subject.'_dti_MD.nii.gz';
	if($subject and -e $dti_md){
		my $order = $ENV{'FSLDIR'}.'/bin/fslstats '.$dti_md.' -l 0 -u '.$up_threshold.' -h '.$nbins;
		my @shist = qx/$order/;
		chomp @shist;
		push @allsums, sum(@shist);
		$nph{$subject} = max(@shist);
	}
}
my $norm = sum(@allsums)/scalar(@allsums);
print "Subject,NPH\n";
foreach my $subject (sort keys %nph){
	my $nphv = $nph{$subject}/$norm;
	print "$subject,$nphv\n";
}
