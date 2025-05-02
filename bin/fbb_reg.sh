#!/bin/sh

export FSL='singularity run --cleanenv -B /nas:/nas -B /old_nas:/old_nas /nas/usr/local/opt/singularity/fsl.simg'
export ANTS="singularity run --cleanenv -B /nas:/nas -B /old_nas:/old_nas -B ${PIPEDIR}/lib/mni:/libdir /nas/usr/local/opt/singularity/ants.simg"

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

td=${wdir}'/.tmp_pet_'${id}
if [ ! -d "$td" ]; then
        mkdir $td
fi
debug=1
${FSL} fslreorient2std ${mri} ${wdir}/${id}_struc
if [ $corr == 1 ]; then 
	${FSL} fslsplit ${src} ${td}/${id}_fbb_ -t
	items=(`ls ${td}/${id}_fbb_*.nii.gz | grep -v reg | grep -v moving`)

#Now get the uncorrected PETs and register to user space MRI
	first=1
	for i in ${!items[*]}; do 
		if [ $first==1 ]; then
			pet_ref=${items[$i]}
			${FSL} imcp ${pet_ref} ${pet_ref%.nii.gz}_reg.nii.gz
			first=0
		else
			${ANTS} antsRegistrationSyNQuick.sh -d 3 -f ${pet_ref} -m ${items[$i]} -t r -o ${items[$i]%.nii.gz}_4mc_;
			${ANTS} antsApplyTransforms -d 3 -r ${pet_ref} -i ${items[$i]} -t ${items[$i]%.nii.gz}_4mc_0GenericAffine.mat -o ${items[$i]%.nii.gz}_mc.nii.gz;
		fi
		# Y aqui abajo las moderneces
		#${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -f ${wdir}/${id}_struc.nii.gz -m ${items[$i]} -t a -o ${items[$i]%.nii.gz}_movingToFixed_ 
		# Apply lineal (a)
		#${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${items[$i]} -t ${items[$i]%.nii.gz}_movingToFixed_0GenericAffine.mat -o ${items[$i]%.nii.gz}_reg.nii.gz
		#${FSLDIR}/bin/imcp ${items[$i]%.nii.gz}_reg ${wdir}/ ;
	done
	a=`for i in ${!items[*]}; do echo " ${items[$i]%.nii.gz}_reg "; done`
	${FSL} fslmerge -t ${td}/${id}_tmp_corr $a
	${FSL} fslmaths ${td}/${id}_tmp_corr -Tmean ${td}/${id}_mean
	${FSL} imcp ${td}/${id}_mean ${wdir}/${id}_mcfbb 
else	
	echo "Only one slice detected, no movement correction allowed"
	${FSL} imcp ${items[0]} ${wdir}/${id}_mcfbb.nii.gz
fi
${ANTS} antsRegistrationSyNQuick.sh -d 3 -f ${wdir}/${id}_struc.nii.gz -m ${wdir}/${id}_mcfbb.nii.gz -t s -o ${td}/${id}_movingToFixed_
${ANTS} antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${wdir}/${id}_mcfbb.nii.gz -t ${td}/${id}_movingToFixed_0GenericAffine.mat -t ${td}/${id}_movingToFixed_1Warp.nii.gz -o ${wdir}/${id}_fbb.nii.gz

if [ $debug = 0 ] ; then
    rm -rf ${td}
fi
