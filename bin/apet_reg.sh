#!/bin/sh

study=$1
shift
id=$1
shift
wdir=$1
shift
src=$1
shift

td=${wdir}'/.tmp_'${id}
if [ ! -d "$td" ]; then
        mkdir $td
fi
debug=0
${FREESURFER_HOME}/bin/mri_convert --in_type mgz --out_type nii ${SUBJECTS_DIR}/${study}_${id}/mri/rawavg.mgz ${wdir}/${id}_struc.nii.gz
${FSLDIR}/bin/fslsplit ${src} ${td}/${id}_piece_ -t
for x in ${td}/${id}_piece_*; do 
	${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -f ${wdir}/${id}_struc.nii.gz -m ${x} -t a -o ${x%.nii.gz}_movingToFixed_; 
	${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${x} -t ${x%.nii.gz}_movingToFixed_0GenericAffine.mat -o ${x%.nii.gz}_reg.nii.gz; 
done
a=`for i in ${td}/*_reg.nii.gz; do echo " $i"; done`
${FSLDIR}/bin/fslmerge -t ${td}/${id}_corr.nii.gz $a
${FSLDIR}/bin/fslmaths ${td}/${id}_corr.nii.gz -Tmean ${wdir}/${id}_pet.nii.gz
if [ $debug = 0 ] ; then
    rm -rf ${td}/*_piece_*
fi 
