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
# Go on now
${FREESURFER_HOME}/bin/mri_convert --in_type mgz --out_type nii ${SUBJECTS_DIR}/${study}_${id}/mri/rawavg.mgz ${wdir}/${id}_struc.nii.gz
${FSLDIR}/bin/fslsplit ${src} ${td}/${id}_piece_ -t
# Si sabes los slices que tienes que cortar haces un crop de la MRI y calculas el movimiento del croped a T1w original
if [[ $slices != 0 ]]; then
	${PIPEDIR}/bin/cutslices.sh ${wdir}/${id}_struc.nii.gz ${td}/${id}_struc_croped.nii.gz ${slices};
	${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -j 1 -f ${wdir}/${id}_struc.nii.gz -m ${td}/${id}_struc_croped.nii.gz -t t -o ${td}/${id}_cropedToFixed_;
fi
# Para cada slice, registro a MRI. Si hay croped lo registro al croped y despues lo muevo al espacio orignal, si no lo hago directamente con el T1w
for x in ${td}/${id}_piece_*; do
       	if [[ $slices != 0 ]]; then
		fslmaths ${x} -sqr -mul ${x} -sqrt ${x%.nii.gz}_mod.nii.gz
		${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -f ${wdir}/${id}_struc_croped.nii.gz -m ${x%.nii.gz}_mod.nii.gz -t a -o ${x%.nii.gz}_movingToCroped_;
		${ANTS_PATH}/antsApplyTransforms -d 3 -r ${td}/${id}_struc_croped.nii.gz -i ${x} -t ${x%.nii.gz}_movingToCroped_0GenericAffine.mat -o ${x%.nii.gz}_reg_croped.nii.gz;
		${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${x%.nii.gz}_reg_croped.nii.gz -t ${td}/${id}_cropedToFixed_0GenericAffine.mat -o ${x%.nii.gz}_reg.nii.gz;
	else
		${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -f ${wdir}/${id}_struc.nii.gz -m ${x} -t a -o ${x%.nii.gz}_movingToFixed_; 
		${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${x} -t ${x%.nii.gz}_movingToFixed_0GenericAffine.mat -o ${x%.nii.gz}_reg.nii.gz; 
	fi
done
a=`for i in ${td}/*_reg.nii.gz; do echo " $i"; done`
${FSLDIR}/bin/fslmerge -t ${td}/${id}_corr.nii.gz $a
${FSLDIR}/bin/fslmaths ${td}/${id}_corr.nii.gz -Tmean ${wdir}/${id}_tau.nii.gz
${FSLDIR}/bin/fslmaths ${wdir}/${id}_tau.nii.gz -bin ${td}/${study}_${id}_tau_mask.nii.gz
if [ $debug = 0 ] ; then
    rm -rf ${td}/*_piece_*
fi 
