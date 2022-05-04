#!/usr/bin/perl
#
# To convert a bunch of CSV files into a single XLS
#
# Copyleft 2022 O. Sotolongo <asqwerty@gmail.com>
#
use strict;
use warnings;
use Text::CSV qw( csv );
use Spreadsheet::Write;

my $idir;
my $ofile;
@ARGV = ("-h") unless @ARGV;
while (@ARGV and $ARGV[0] =~ /^-/) {
	$_ = shift;
	last if /^--$/;
	if (/^-i/) { $idir = shift; chomp($idir);}
	if (/^-o/) { $ofile = shift; chomp($ofile);}
}
die "Should supply results directory\n" unless $idir;
die "Should output filename\n" unless $ofile;

$ofile =~ s/\.(\w*)?$/.xls/;
opendir (DIR, $idir);
my @ifiles = grep(/\.csv/, readdir(DIR));
close DIR;

my $workbook = Spreadsheet::Write->new(file => $ofile, sheet => 'INFO');
my $infof = $idir.'/INFO.csv';
if( -e $infof ){
	my $inf_data =  csv (in => $infof);
	for my $i (0 .. $#{$inf_data}) {
		my $row = $inf_data->[$i];
		$workbook->addrow($row);
	}
}
foreach my $ifile (@ifiles){
	unless( $ifile eq 'INFO.csv'){ 
		my $ipath = $idir.'/'.$ifile; 
		my $idata = csv (in => $ipath); # as array of array
		(my $shname = $ifile) =~ s/\.csv$//;
		$workbook->addsheet($shname);
		for my $i (0 .. $#{$idata}) {
			my $row = $idata->[$i];
			$workbook->addrow($row);
		}
	}	
}
$workbook->close();
