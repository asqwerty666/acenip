#!/bin/sh

study=$1
shift

id=$1
shift

dir=$1
shift

debug=0

#First get the freesurfer processed MRIs

	${FREESURFER_HOME}/bin/mri_convert --in_type mgz --out_type nii --conform ${SUBJECTS_DIR}/${study}_${id}/mri/T1.mgz ${dir}/${id}_tmp.nii.gz
	${FSLDIR}/bin/fslreorient2std ${dir}/${id}_tmp ${dir}/${id}_struc
	${FREESURFER_HOME}/bin/mri_convert --in_type mgz --out_type nii --conform ${SUBJECTS_DIR}/${study}_${id}/mri/brain.mgz ${dir}/${id}_tmp_brain.nii.gz
	${FSLDIR}/bin/fslreorient2std ${dir}/${id}_tmp_brain ${dir}/${id}_struc_brain 


if [ $debug = 0 ] ; then
    rm ${dir}/${id}_tmp* 
fi
