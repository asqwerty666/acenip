#!/bin/sh
subject=$1
shift

tmp_dir=$1
shift

label=$1
shift
mri_label2vol --label $SUBJECTS_DIR/${subject}/labels/lh.${label} --temp $SUBJECTS_DIR/${subject}/mri/rawavg.mgz --subject ${subject} --hemi lh --o ${tmp_dir}/lh.${label}.nii.gz --proj frac 0 1 .1 --fillthresh .3 --reg ${tmp_dir}/lh.register.dat
fslreorient2std ${tmp_dir}/lh.${label} ${tmp_dir}/lh.${label}_ro
mri_label2vol --label $SUBJECTS_DIR/${subject}/labels/rh.${label} --temp $SUBJECTS_DIR/${subject}/mri/rawavg.mgz --subject ${subject} --hemi rh --o ${tmp_dir}/rh.${label}.nii.gz --proj frac 0 1 .1 --fillthresh .3 --reg ${tmp_dir}/rh.register.dat
fslreorient2std ${tmp_dir}/rh.${label} ${tmp_dir}/rh.${label}_ro
fslmaths ${tmp_dir}/lh.${label}_ro -add ${tmp_dir}/rh.${label}_ro ${tmp_dir}/${label}
