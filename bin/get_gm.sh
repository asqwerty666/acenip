#!/bin/sh

study=$1
shift

id=$1
shift

dir=$1
shift

debug=0

#First get the freesurfer processed aseg.mgz
${FREESURFER_HOME}/bin/mri_label2vol --seg ${SUBJECTS_DIR}/${study}_${id}/mri/aseg.mgz --temp ${SUBJECTS_DIR}/${study}_${id}/mri/nu.mgz --o ${dir}/${id}_tmp_aseg.mgz --regheader ${SUBJECTS_DIR}/${study}_${id}/mri/aseg.mgz
${FREESURFER_HOME}/bin/mri_convert --in_type mgz --out_type nii ${dir}/${id}_tmp_aseg.mgz ${dir}/${id}_tmp_aseg.nii.gz
${FSLDIR}/bin/fslreorient2std ${dir}/${id}_tmp_aseg ${dir}/${id}_aseg
#Where is the cerebellum
cm=(6 7 8 45 46 47)
#cm=(7 46)
tada=""
first=1
for acm in "${cm[@]}";
do 
	${FSLDIR}/bin/fslmaths ${dir}/${id}_aseg -uthr ${acm} -thr ${acm} -div ${acm} ${dir}/${id}_tmp_cb_${acm};
	if [[ "$tada" == "" ]]; then  
		tada="${tada}${dir}/${id}_tmp_cb_${acm}"; 
	else 
		tada="${tada} -add ${dir}/${id}_tmp_cb_${acm}"; 
	fi;
done
tada="$tada ${dir}/${id}_cmask"
${FSLDIR}/bin/fslmaths $tada
#Now get thw WM
${FREESURFER_HOME}/bin/mri_label2vol --seg ${SUBJECTS_DIR}/${study}_${id}/mri/wm.mgz --temp ${SUBJECTS_DIR}/${study}_${id}/mri/nu.mgz --o ${dir}/${id}_tmp_wm.mgz --regheader ${SUBJECTS_DIR}/${study}_${id}/mri/wm.mgz
${FREESURFER_HOME}/bin/mri_convert --in_type mgz --out_type nii ${dir}/${id}_tmp_wm.mgz ${dir}/${id}_tmp_wm.nii.gz
${FSLDIR}/bin/fslreorient2std ${dir}/${id}_tmp_wm ${dir}/${id}_wm
#And get the masks
${FSLDIR}/bin/fslmaths ${dir}/${id}_aseg -bin ${dir}/${id}_aseg_mask
${FSLDIR}/bin/fslmaths ${dir}/${id}_wm -bin ${dir}/${id}_wm_mask
${FSLDIR}/bin/fslmaths ${dir}/${id}_aseg_mask -sub ${dir}/${id}_wm_mask ${dir}/${id}_gm_mask_wc
${FSLDIR}/bin/fslmaths ${dir}/${id}_gm_mask_wc -sub ${dir}/${id}_cmask ${dir}/${id}_gm_mask
${FSLDIR}/bin/fslmaths ${dir}/${id}_struc_brain -mas ${dir}/${id}_gm_mask ${dir}/${id}_struc_GM
#Ahora voy a registrar la GM a espacio MNI
#${ANTS_PATH}/antsRegistrationSynQuick.sh -d 3 -f ${FSLDIR}/data/standard/tissuepriors/avg152T1_brain.img -m ${dir}/${id}_struc_brain.nii.gz -o ${dir}/${id}_GM2T_ -t s
#${ANTS_PATH}/antsApplyTransforms -d 3 -i ${dir}/${id}_GM.nii.gz -r ${FSLDIR}/data/standard/tissuepriors/avg152T1_gray.img -t ${dir}/${id}_GM2T_1Warp.nii.gz -t ${dir}/${id}_GM2T_0GenericAffine.mat -o ${dir}/${id}_GM_to_T.nii.gz
if [ $debug = 0 ] ; then
    rm ${dir}/${id}_tmp* 
fi
