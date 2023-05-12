#!/usr/bin/perl 
use strict; 
use warnings; 
use Text::CSV; 
my $csv = Text::CSV->new( { binary => 1, eol => "\n" } ); 
while ( my $row = $csv->getline( \*ARGV ) ) {     
	s/\n/ /g for @$row;     
	$csv->print( \*STDOUT, $row ); 
}
