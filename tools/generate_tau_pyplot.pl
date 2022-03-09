#!/usr/bin/perl
use strict;
use warnings;
use NEURO4 qw(check_pet check_subj load_project print_help check_or_make cut_shit);
use Data::Dump qw(dump);
my $tracer;
my $subject;
my $mod = 'unc';
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	if (/^-tracer/) {$tracer = shift; chomp($tracer);}
	if (/^-id/) {$subject = shift; chomp($subject);}
	if (/^-mod/) {$mod = shift; chomp($mod);}
}
my $study = shift;
die "Should supply project name\n" unless $study;
die "Should supply subject ID\n" unless $subject;
my %std = load_project($study);
my $ifile = $std{'DATA'}.'/'.$study.'_tau_suvr_'.$tracer.'_'.$mod.'.csv';
open IDF, "<$ifile";
my $seeker;
my %taud;
my @levels;
while(<IDF>){
	unless ($seeker){
		@levels = split ", ", $_;
		chomp @levels;
	}else{
		my @values = split ", ", $_;
		chomp @values;
		if ($values[0] eq $subject){
			for (my $i = 1; $i < scalar @values; $i++){
				$taud{$levels[$i]} = $values[$i] unless $levels[$i] eq 'extra';
			}
		}
	}
	$seeker++;
}
close IDF;
#dump %taud;
my $odata = "data = {\n";
foreach my $tag (sort keys %taud){
	my $libfile = $ENV{'PIPEDIR'}.'/lib/tau/'.$tag.'.roi';
	open ILF, "<$libfile";
	while (<ILF>){
		my ($hand, $roi) = /\d+,(\w)_(\w+)/;
		unless ($hand eq 'R'){
			$odata.="'".$roi."_left': ".$taud{$tag}.",\n";
			$odata.="'".$roi."_right': ".$taud{$tag}.",\n";
		}
	}
	close ILF;
}
$odata.="}\n";
my $pfile = $std{'DATA'}.'/'.$study.'_'.$tracer.'_'.$subject.'_'.$mod.'.py';
open OPF, ">$pfile";
print OPF '#!/usr/bin/python3'."\n";
print OPF "import ggseg\n";
print OPF "$odata\n";
print OPF "ggseg.plot_dk(data, cmap='Spectral', figsize=(15,15),";
print OPF "background='k', edgecolor='w', bordercolor='gray',";
print OPF "ylabel='PET-".$tracer." SUVR', title='".$subject."')\n";
close OPF;

