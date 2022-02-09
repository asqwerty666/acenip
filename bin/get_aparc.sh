#!/bin/sh

study=$1
shift

id=$1
shift

dir=$1
shift

debug=0

#First get the freesurfer processed aparc+aseg.mgz
${FREESURFER_HOME}/bin/mri_label2vol --seg ${SUBJECTS_DIR}/${study}_${id}/mri/aparc+aseg.mgz --temp ${SUBJECTS_DIR}/${study}_${id}/mri/rawavg.mgz --o ${dir}/${id}_tmp_aseg.mgz --regheader ${SUBJECTS_DIR}/${study}_${id}/mri/aparc+aseg.mgz
${FREESURFER_HOME}/bin/mri_convert --in_type mgz --out_type nii ${dir}/${id}_tmp_aseg.mgz ${dir}/${id}_tmp_aseg.nii.gz
${FSLDIR}/bin/fslreorient2std ${dir}/${id}_tmp_aseg ${dir}/${id}_aseg

if [ $debug = 0 ] ; then
    rm ${dir}/${id}_tmp* 
fi
