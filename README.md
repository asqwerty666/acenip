# ACE NeuroImaging Pipeline 

ACE Neuroimaging pipeline is a collection of perl and bash scripts (mostly) that are used to
run neuroimaging analysis with popular software packages like FSL, Freesurfer or ANTs. 

Current development version of the pipeline (v0.6) is intended to be used in conjunction 
with XNAT and is completed integrated into the SLUM cluster. 

See https://detritus.fundacioace.com/wiki/doku.php?id=neuroimagen:pipe04_user_en 
for a description of common methods (very old but almost still valid)

## Dependencies

  - XNAT
  - dcm2bids
  - dicom3tools
  - FSL
  - Freesurfer
  - ANTs
  - Convert3D
  - fmriprep

## Extras

There is two libraries that could be downloaded and used independently of the pipeline. 

  - SLURMACE.pm is basically a Perl helper to send sbatch commands to SLURM. You do not need to worry about sbatch syntax or rules. Only need to fill out the proper hash with sbatch relevant information. See more at [the libray readme](doc/SLURMACE.md).
  - XNATACE.pm is a collection of functions that use the XNAT API to put or get information, including downloading or uploading files. This include open a session and an almost complete interaction with projects, subjects or eperiments data. See full docs at [XNATACE readme](doc/XNATACE.md)
