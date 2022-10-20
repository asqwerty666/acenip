# SLURM

This module contains just a function to send the jobs to SLURM 
from the Perl scripts

- send2slurm

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

    usage: my $job\_id = send2slurm(\\%job\_properties);

    Warning email: By default, if an empty HASH is passed to the function, 
    a no command sbatch script is launched
    with _--mail-type=END_ option. The intention is that this could be used to
    warn at the end of any launched swarm. Also, by changing **mailtype** but 
    ommiting the **command** value you can force the function to execute 
    an empty sbatch job with whatever warning behavior that you choose.

    Dependencies: If dependencies are going to be used, you need to pass to
    the function the full string that SLURM expects. That is, you can pass something 
    like _singleton_ or _after:000000_ or even _afterok:000000,000001,000002_. 
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
    **dependency** option could be safely ignored. But notice that, if you are 
    reusing a HASH then this key should be deleted from it. 

- wait4jobs

    This function uses slurm to ask if given jobs are running. User should supply an array with all the
    jobs that function should wait for. Once all the jobs have finished, the control is returned to main 
    program

    usage: wait4jobs(@jobs\_list) 
