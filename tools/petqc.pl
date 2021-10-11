#!/usr/bin/perl
#print env
use strict; use warnings;
use CGI ':standard';
use File::Temp qw( :mktemp tempdir);
use Data::Dump qw(dump);

our $host="http://brick04:8080";
our $tmp_dir = '/var/www/html/petqc'; 

my %pdata;
my @defis = ('No Pass', 'Pass');
my %redefis = ('No Pass' => 0, 'Pass' => 1);
my $q = new CGI;
print $q->header("text/html");
print $q->start_html( -title => "PET QC report tool");

sub get_petqc {
	my ($xprj, $user, $passwd) = @_;
	my %outdata;
	my $subjects_list = mktemp($tmp_dir.'/sbjsfileXXXXX');
	my $order = 'curl -X GET -u "'.$user.':'.$passwd.'" "'.$host.'/data/projects/'.$xprj.'/subjects?format=json" | jq ".ResultSet.Result[].ID" | sed \'s/"/,/g\'';
	my $tmplist = qx/$order/;
	my @sbjs = split /,/, $tmplist;
	chomp @sbjs;
	foreach my $sbj (@sbjs){
		#print $q->p("$sbj");
		$order = 'curl -X GET -u "'.$user.':'.$passwd.'" "'.$host.'/data/projects/'.$xprj.'/subjects/'.$sbj.'/experiments?xsiType=xnat:petSessionData" 2>/dev/null | jq ".ResultSet.Result[].ID" | sed \'s/"//g\'';
		my $xpet = qx/$order/;
		chomp $xpet;
		$order = 'curl -X GET -u "'.$user.':'.$passwd.'" "'.$host.'/data/experiments/'.$xpet.'/resources/MRI/files/mriSessionMatch.json" 2>/dev/null | jq ".ResultSet.Result[].qa"';
		my $qa = qx/$order/;
		chomp $qa;
		if ($xpet){
			#$outdata{$sbj}{'experiment'} = $xpet;
	        	#$outdata{$sbj}{'qa'} = $qa;
			my $outimg = $tmp_dir.'/'.$sbj.'.gif';
			$order = 'curl -X GET -u "'.$user.':'.$passwd.'" "'.$host.'/data/experiments/'.$xpet.'/resources/MRI/files/'.$sbj.'_fbb_mni.gif" -o '.$outimg;
			system($order);
			if (-f $outimg) {
				$outdata{$sbj}{'qa'} = $qa;
				$outdata{$sbj}{'experiment'} = $xpet;
				($outdata{$sbj}{'img'}) = $outimg =~ /^\/var\/www\/html\/(.*?\/.*?)$/; 
			}
		}
	}
	
	return %outdata;
}


sub put_petqc {
	my $xprj = shift;
	my $user = shift;
	my $passwd = shift;
	my %qcs = @_;
	my $tmpfile = $tmp_dir.'/tmp.json';
	foreach my $xpx (sort keys %qcs){
		my $order = 'curl -X GET -u "'.$user.':'.$passwd.'" "'.$host.'/data/experiments/'.$xpx.'/resources/MRI/files/mriSessionMatch.json" 2>/dev/null';
		my $resp = qx/$order/;
		$resp =~ s/,"qa":\d,/"qa":$qcs{$xpx},/;
		open TDF, ">$tmpfile" or return 500;
		print TDF $resp;
		close TDF;
		$order = 'curl -X PUT -u "'.$user.':'.$passwd.'" "'.$host.'/data/experiments/'.$xpx.'/resources/MRI/files/mriSessionMatch.json?overwrite=true" -F file="@'.$tmpfile.'"';
		#print $q->p("$order");
		system($order);
	}
	return 0;
}
if( $ENV{REQUEST_METHOD} eq 'POST'){
	my %params = map { $_ => scalar $q->param($_) } $q->param() ;
	if(exists($params{'auth'})){
		%pdata = get_petqc($params{'xproject'}, $params{'username'}, $params{'passwd'});
		print $q->start_form( -method=>"POST", -action=>"/cgi-bin/petqc.pl" );
		print $q->hidden( -name=>"username", -value=>$params{'username'});
		print $q->hidden( -name=>"passwd", -value=>$params{'passwd'});
		print $q->hidden( -name=>"xproject", -value=>$params{'xproject'});
		print "<table>";
		foreach my $sbj (sort keys %pdata) {
			print "<tr><td>";
			print $q->p(img({src => '/'.$pdata{$sbj}{'img'}}));
			print "</td><td>";
			print $q->p($sbj);
			print radio_group(-name=>$pdata{$sbj}{experiment}, -values=>['No Pass','Pass'], -default=>$defis[$pdata{$sbj}{'qa'}]);
			print "</td></tr>";
		}
		print "</table>";
		print $q->submit( -name=>"evaluate", -value=>"Submit");
	}elsif(exists($params{'evaluate'})){
		my %xpxs;
		foreach my $udata ( sort keys %params ){
			if( $udata =~ /XNAT.*/){
				$xpxs{$udata} = $redefis{$params{$udata}};
			}
		}
		my $res = put_petqc($params{'xproject'}, $params{'username'}, $params{'passwd'}, %xpxs);
		print $q->p(img({src => '/petqc/chuck_finley.jpg'})) unless $res;

	}
}else{
	print $q->start_form( -method=>"POST", -action=>"/cgi-bin/petqc.pl" );
	print $q->p("XNAT project:" , $q->textfield( -name=>"xproject"));
	print $q->p("User:" , $q->textfield( -name=>"username"));
	print $q->p("Password:", $q->textfield( -name=>"passwd"));
	print $q->submit( -name=>"auth", -value=>"Submit");
	print $q->end_form;
}

print $q->end_html;

