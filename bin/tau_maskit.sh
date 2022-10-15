#!/bin/sh

study=$1
shift
id=$1
shift
wdir=$1
shift

td=${wdir}'/.tmp_'${id}
if [ ! -d "$td" ]; then
        mkdir $td
fi
#debug=0
if [ ! -f ${td}/rois/register.dat ]; then
        mkdir -p ${td}/rois/;
        ${FREESURFER_HOME}/bin/tkregister2 --mov $SUBJECTS_DIR/${study}_${id}/mri/rawavg.mgz --noedit --s ${study}_${id} --regheader --reg ${td}/rois/register.dat;
        sleep 5;
fi
if [ ! -f ${td}/all_aseg.nii.gz ]; then
        ${FREESURFER_HOME}/bin/mri_label2vol --seg $SUBJECTS_DIR/${study}_${id}/mri/aparc+aseg.mgz --temp $SUBJECTS_DIR/${study}_${id}/mri/rawavg.mgz --o ${td}/all_aseg.nii.gz --reg ${td}/rois/register.dat;
        sleep 5;
fi
if [ ! -f ${td}/rois/register.dat ]; then
        mkdir -p ${td}/rois/;
        ${FREESURFER_HOME}/bin/tkregister2 --mov $SUBJECTS_DIR/${study}_${id}/mri/rawavg.mgz --noedit --s ${study}_${id} --regheader --reg ${td}/rois/register.dat;
        sleep 5;
fi
if [ ! -f ${td}/all_aseg.nii.gz ]; then
        ${FREESURFER_HOME}/bin/mri_label2vol --seg $SUBJECTS_DIR/${study}_${id}/mri/aparc+aseg.mgz --temp $SUBJECTS_DIR/${study}_${id}/mri/rawavg.mgz --o ${td}/all_aseg.nii.gz --reg ${td}/rois/register.dat;
        sleep 5;
fi

${FSLDIR}/bin/fslmaths ${wdir}/${id}_tau.nii.gz -bin ${td}/${study}_${id}_tau_mask.nii.gz
