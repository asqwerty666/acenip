#!/bin/sh

study=$1
shift
id=$1
shift
wdir=$1
shift
src=$1
shift
slices=$1
shift

td=${wdir}'/.tmp_'${id}
if [ ! -d "$td" ]; then
        mkdir $td
fi
debug=0
# Clean the shit first
rm -rf ${td}/*_piece_*
# Get FS register data
# OK, you won't need this really here but this way  you can avoid future errors
if [ ! -f ${td}/rois/register.dat ]; then
        mkdir -p ${td}/rois/;
        ${FREESURFER_HOME}/bin/tkregister2 --mov $SUBJECTS_DIR/${study}_${id}/mri/rawavg.mgz --noedit --s ${study}_${id} --regheader --reg ${td}/rois/register.dat;
        sleep 5;
fi
if [ ! -f ${td}/all_aseg.nii.gz ]; then
        ${FREESURFER_HOME}/bin/mri_label2vol --seg $SUBJECTS_DIR/${study}_${id}/mri/aparc+aseg.mgz --temp $SUBJECTS_DIR/${study}_${id}/mri/rawavg.mgz --o ${td}/all_aseg.nii.gz --reg ${td}/rois/register.dat;
        sleep 5;
fi

# Go on now
${FREESURFER_HOME}/bin/mri_convert --in_type mgz --out_type nii ${SUBJECTS_DIR}/${study}_${id}/mri/rawavg.mgz ${wdir}/${id}_struc.nii.gz
${FSLDIR}/bin/fslsplit ${src} ${td}/${id}_piece_ -t
# Si sabes los slices que tienes que cortar haces un crop de la MRI y calculas el movimiento del croped a T1w original
if [[ $slices != 0 ]]; then
	${PIPEDIR}/bin/cutslices.sh ${wdir}/${id}_struc.nii.gz ${td}/${id}_struc_croped.nii.gz ${slices};
	${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -j 1 -f ${wdir}/${id}_struc.nii.gz -m ${td}/${id}_struc_croped.nii.gz -t t -o ${td}/${id}_cropedToFixed_;
fi
# Para cada slice, registro a MRI. Si hay croped lo registro al croped y despues lo muevo al espacio orignal, si no lo hago directamente con el T1w
first=1
for x in ${td}/${id}_piece_*; do
	if [ $first==1 ]
	then
		pet_ref=${x}
		imcp ${x} ${x%.nii.gz}_mc.nii.gz
		first=0
	else
		${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -f ${pet_ref} -m ${x} -t r -o ${x%.nii.gz}_4mc_
		${ANTS_PATH}/antsApplyTransforms -d 3 -r ${pet_ref} -i ${x} -t ${x%.nii.gz}_4mc_0GenericAffine.mat -o ${x%.nii.gz}_mc.nii.gz 
	fi
done
a=`for i in ${td}/*_mc.nii.gz; do echo " $i"; done`
${FSLDIR}/bin/fslmerge -t ${td}/${id}_mctmp.nii.gz $a
${FSLDIR}/bin/fslmaths ${td}/${id}_mctmp.nii.gz -Tmean ${wdir}/${id}_mcpet.nii.gz
rm ${td}/${id}_mctmp.nii.gz ${td}/*_mc.nii.gz

if [[ $slices != 0 ]]; then
	${FREESURFER_HOME}/bin/mri_coreg --ref-fwhm 8 --ref ${td}/${id}_struc_croped.nii.gz --mov ${wdir}/${id}_mcpet.nii.gz --reg ${wdir}/${id}_coreg.lta
	${FREESURFER_HOME}/bin/mri_convert --apply_transform ${wdir}/${id}_coreg.lta ${wdir}/${id}_mcpet.nii.gz ${wdir}/${id}_reg_croped.nii.gz
	${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${wdir}/${id}_reg_croped.nii.gz -t ${td}/${id}_cropedToFixed_0GenericAffine.mat -o ${wdir}/${id}_tau.nii.gz;
else
	${FREESURFER_HOME}/bin/mri_coreg --ref-fwhm 8 --ref ${wdir}/${id}_struc.nii.gz --mov ${wdir}/${id}_mcpet.nii.gz --reg ${wdir}/${id}_coreg.lta
	${FREESURFER_HOME}/bin/mri_convert --apply_transform ${wdir}/${id}_coreg.lta ${wdir}/${id}_mcpet.nii.gz ${wdir}/${id}_tau.nii.gz
fi
${FSLDIR}/bin/fslmaths ${wdir}/${id}_tau.nii.gz -bin ${td}/${study}_${id}_tau_mask.nii.gz
if [ $debug = 0 ] ; then
    rm -rf ${td}/*_piece_*
fi 
