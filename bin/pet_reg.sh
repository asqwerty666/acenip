#!/bin/sh

study=$1
shift
id=$1
shift
wdir=$1
shift
src=$1
shift
mri=$1
shift
corr=$1
shift
ants='singularity run --cleanenv -B /nas:/nas -B /old_nas:/old_nas -B '${FSLDIR}':/fsldir -B /ruby:/ruby /nas/usr/local/opt/singularity/ants.simg'
debug=0
${FSLDIR}/bin/fslreorient2std ${mri} ${wdir}/${id}_struc
dim=$(${FSLDIR}/bin/fslinfo ${src} | grep "^dim4" | awk '{print $2}')
if [[ ${dim} != "1" ]]; then 
	mkdir ${wdir}/${id}_pieces
	${FSLDIR}/bin/fslsplit ${src} ${wdir}/${id}_pieces/${id}_pet_ -t
	frst=true
#Now get the uncorrected PETs and register to user space MRI
	for i in ${wdir}/${id}_pieces/${id}_pet_*; do
		echo "${frst}"
		if [[ "${frst}" == "true" ]]; then
			pet_ref=${i}
			frst=false
			imcp ${i} ${i%.nii.gz}_mc.nii.gz
			echo "PET reference is ${i}, $frst"
		else
			${ants} antsRegistrationSyNQuick.sh -d 3 -f ${pet_ref} -m ${i} -t r -o ${i%.nii.gz}_4mc_;
			${ants} antsApplyTransforms -d 3 -r ${pet_ref} -i ${i} -t ${i%.nii.gz}_4mc_0GenericAffine.mat -o ${i%.nii.gz}_mc.nii.gz;
		fi
	done
	stl=`for i in ${wdir}/${id}_pieces/*_mc.nii.gz; do echo " $i"; done`
	${FSLDIR}/bin/fslmerge -t ${wdir}/${id}_pieces/corrected.nii.gz ${stl}
	${FSLDIR}/bin/fslmaths ${wdir}/${id}_pieces/corrected.nii.gz -Tmean ${wdir}/${id}_pieces/pet.nii.gz
	${ants} antsRegistrationSyNQuick.sh  -d 3 -f ${wdir}/${id}_struc.nii.gz -m ${wdir}/${id}_pieces/pet.nii.gz -t a -o ${wdir}/${id}_movingToFixed_
	${ants} antsApplyTransforms -d 3 -r  ${wdir}/${id}_struc.nii.gz -i ${wdir}/${id}_pieces/pet.nii.gz -t ${wdir}/${id}_movingToFixed_0GenericAffine.mat -o ${wdir}/${id}_pet.nii.gz
	if [ $debug = 0 ] ; then 
		rm -rf ${wdir}/${id}_pieces
	fi
else
	${ants} antsRegistrationSyNQuick.sh -d 3 -f ${wdir}/${id}_struc.nii.gz -m ${src} -t s -o ${td}/${id}_movingToFixed_
	${ants}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${src} -t ${td}/${id}_movingToFixed_0GenericAffine.mat -t ${td}/${id}_movingToFixed_1Warp.nii.gz -o ${wdir}/${id}_pet.nii.gz
fi

${ants} antsRegistrationSyN.sh -d 3 -f /fsldir/data/standard/MNI152_T1_2mm.nii.gz -m ${wdir}/${id}_struc.nii.gz -j 1 -t s -o ${wdir}/${id}_t12mni_
${ants} antsApplyTransforms -d 3 -r /fsldir/data/standard/MNI152_T1_2mm.nii.gz -i ${wdir}/${id}_pet.nii.gz -t ${wdir}/${id}_t12mni_0GenericAffine.mat -t ${wdir}/${id}_t12mni_1Warp.nii.gz -o ${wdir}/${id}_pet_mni.nii.gz

