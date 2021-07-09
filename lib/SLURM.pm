#!/usr/bin/perl

# Copyright 2021 O. Sotolongo <asqwerty@gmail.com>

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
package SLURM;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(send2slurm);
our @EXPORT_OK = qw(send2slurm);
our %EXPORT_TAGS =(all => qw(send2slurm), usual => qw(send2slurm));

our $VERSION = 0.1;

sub define_task{
# default values for any task
	my %task;
	$task{'mem_per_cpu'} = '4G';
	$task{'cpus'} = 1;
	$task{'time'} = '2:0:0';
	my $label = sprintf("%03d", rand(1000));
	$task{'filename'} = 'slurm_'.$label.'.sh';
	$task{'output'} = 'slurm_'.$label.'.out';
	$task{'order'} = 'sbatch --parsable '.$task{'filename'};
	$task{'job_name'} = 'myjob';
	$task{'mailtype'} = 'FAIL,TIME_LIMIT,STAGE_OUT';
	return %task;
}

sub send2slurm{
	my %task = %{$_[0]};
	my %dtask = define_task();
	my $scriptfile;
        if(exists($task{'filename'}) && $task{'filename'}){
                $scriptfile = $task{'filename'};
        }else{
                $scriptfile = $dtask{'filename'};
        }
        open ESS, ">$scriptfile" or die 'Could not create slurm script\n';
	print ESS '#!/bin/bash'."\n";
	print ESS '#SBATCH -J ';
	if(exists($task{'job_name'}) && $task{'job_name'}){
		print ESS $task{'job_name'}."\n";
	}else{
		print ESS $dtask{'job_name'}."\n";
	}
	if(exists($task{'cpus'}) && $task{'cpus'}){
		print ESS '#SBATCH -c '.$task{'cpus'}."\n";
		print ESS '#SBATCH --mem-per-cpu=';
		if(exists($task{'mem_per_cpu'}) && $task{'mem_per_cpu'}){
			print ESS $task{'mem_per_cpu'}."\n";
		}else{
			print ESS $dtask{'mem_per_cpu'}."\n";
		}
	}
	if(exists($task{'time'}) && $task{'time'}){
		print ESS '#SBATCH --time='.$task{'time'}."\n";
	}
	if(exists($task{'output'}) && $task{'output'}){
                print ESS '#SBATCH -o '.$task{'output'}.'-%j'."\n";
        }else{
		print ESS '#SBATCH -o '.$dtask{'output'}.'-%j'."\n";
	}
	print ESS '#SBATCH --mail-user='."$ENV{'USER'}\n";
	if(exists($task{'partition'}) && $task{'partition'}){
		print ESS '#SBATCH -p '.$task{'partition'}."\n";
	}
	if(exists($task{'command'}) && $task{'command'}){
		if(exists($task{'mailtype'}) && $task{'mailtype'}){
			print ESS '#SBATCH --mail-type='.$task{'mailtype'}."\n";
		}else{
			print ESS '#SBATCH --mail-type='.$dtask{'mailtype'}."\n";
		}
		print ESS $task{'command'}."\n";
	}else{
		print ESS '#SBATCH --mail-type=END'."\n";
		print ESS ":\n";
	}
	close ESS;
	my $order;
	if(exists($task{'dependency'}) && $task{'dependency'}){
		$order = 'sbatch --parsable --dependency='.$task{'dependency'}.' '.$scriptfile;
	}else{
		$order = 'sbatch --parsable '.$scriptfile;
	}
	my $code = qx/$order/;
	chomp $code;
	return $code;
}


