#!/bin/sh
subject=$1
shift

tmp_dir=$1
shift

if [ ! -f ${tmp_dir}/register.dat ]; then 
	if [  ! -d ${tmp_dir} ]; then mkdir -p ${tmp_dir}; fi;
	tkregister2 --mov $SUBJECTS_DIR/${subject}/mri/rawavg.mgz --noedit --s ${subject} --regheader --reg ${tmp_dir}/register.dat;
fi
if [ ! -f ${tmp_dir}/all_aseg.nii.gz ]; then
	mri_label2vol --seg $SUBJECTS_DIR/${subject}/mri/aseg.mgz --temp $SUBJECTS_DIR/${subject}/mri/rawavg.mgz --o ${tmp_dir}/all_aseg.nii.gz --reg ${tmp_dir}/register.dat;
fi
${FSLDIR}/bin/fslmaths ${tmp_dir}/all_aseg.nii.gz -uthr 2  -thr 2 -div 2 ${tmp_dir}/lhwm
${FSLDIR}/bin/fslmaths ${tmp_dir}/all_aseg.nii.gz -uthr 41  -thr 41 -div 41 ${tmp_dir}/rhwm
${FSLDIR}/bin/fslmaths ${tmp_dir}/lhwm -add ${tmp_dir}/rhwm -bin ${tmp_dir}/wm_mask.nii.gz 
