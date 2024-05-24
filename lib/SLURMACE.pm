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
package SLURMACE;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(send2slurm wait4jobs);
our @EXPORT_OK = qw(send2slurm wait4jobs);
our %EXPORT_TAGS =(all => qw(send2slurm wait4jobs), usual => qw(send2slurm wait4jobs));

our $VERSION = 0.2;

# Changes
#
# v0.1 First release
# v0.2 wait4jobs added

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

=head1 SLURM

This module contains just a function to send the jobs to SLURM 
from the Perl scripts

=over

=item send2slurm

The function takes a HASH as input where all the information 
relative to the job should be stored. No data is mandatory 
inside the input HASH, since the minimal values are automagicaly
asigned by default as a constructor (no really, but anyway).

Take into account that this subroutine only pass the parameters 
to SLURM. So, the logic behind your actions should correspond
to what you want to do in any case, exactly as if you were 
writing sbatch scripts.

The managed options for SLURM jobs are:

	- filename: File where the sbatch script will be stored
	- job_name: Job name for SLURM (-J) 
	- cpus: Number of CPUs to be used by each job (-c)
	- mem_per_cpu: Amount of memory to be used for each CPU (--mem-per-cpu)
	- time: Maximum time that the job will be allowed to run (--time)
	- output: File where the sbatch script output will be stored (-o)
	- partition: SLURM partition to be used (-p)
	- gres: GPUs to be used (--gres)
	- command: Command to be executed at sbatch script
	- mailtype: Type of warning to be emailed (--mail-type)
	- dependency: Full dependency string to be used at sbatch execution (--dependency), see more below

The function returns the jobid of the queued job, so it can be used to 
build complex workflows.

usage: my $job_id = send2slurm(\%job_properties);

Warning email: By default, if an empty HASH is passed to the function, 
a no command sbatch script is launched
with I<--mail-type=END> option. The intention is that this could be used to
warn at the end of any launched swarm. Also, by changing B<mailtype> but 
ommiting the B<command> value you can force the function to execute 
an empty sbatch job with whatever warning behavior that you choose.

Dependencies: If dependencies are going to be used, you need to pass to
the function the full string that SLURM expects. That is, you can pass something 
like I<singleton> or I<after:000000> or even I<afterok:000000,000001,000002>. 
This last can be build, by example, storing every previous jobid into an ARRAY
and passing then as,

	...
		my $jobid = send2slurm(\%previous);
		push @jobids, $jobid;
	...
	$task{'dependency'} = 'afterok:'.join(',',@jobids);
	...
	send2slurm(\%task);

Of course, if dependencies are not going to be used, the 
B<dependency> option could be safely ignored. But notice that, if you are 
reusing a HASH then this key should be deleted from it. 


=cut

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
	if(exists($task{'gres'}) && $task{'gres'}){
		print ESS '#SBATCH --gres='.$task{'gres'}."\n";
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

=item wait4jobs

This function uses slurm to ask if given jobs are running. User should supply an array with all the
jobs that function should wait for. Once all the jobs have finished, the control is returned to main 
program

usage: wait4jobs(@jobs_list) 

=cut

sub wait4jobs{
	my $jlist = join ',',@_;
	my $status;
	do {
		sleep 60;
		$status = qx/squeue -j $jlist | grep -v JOBID/;
		#print "jobs still running\n" if $status;
	} while($status);
}

=back
