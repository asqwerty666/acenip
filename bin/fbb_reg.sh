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

td=${wdir}'/.tmp_pet_'${id}
if [ ! -d "$td" ]; then
        mkdir $td
fi
debug=1
${FSLDIR}/bin/fslreorient2std ${mri} ${wdir}/${id}_struc
if [ $corr = 1 ]; then 
	${FSLDIR}/bin/fslsplit ${src} ${td}/${id}_fbb_ -t
	items=(`ls ${td}/${id}_fbb_*.nii.gz | grep -v reg | grep -v moving`)

#Now get the uncorrected PETs and register to user space MRI
	for i in ${!items[*]}; do 
		# Y aqui abajo las moderneces
		${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -f ${wdir}/${id}_struc.nii.gz -m ${items[$i]} -t a -o ${items[$i]%.nii.gz}_movingToFixed_ 
		# Apply lineal (a)
		${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${items[$i]} -t ${items[$i]%.nii.gz}_movingToFixed_0GenericAffine.mat -o ${items[$i]%.nii.gz}_reg.nii.gz
		${FSLDIR}/bin/imcp ${items[$i]%.nii.gz}_reg ${wdir}/ ;
	done
	a=`for i in ${!items[*]}; do echo " ${items[$i]%.nii.gz}_reg "; done`
	${FSLDIR}/bin/fslmerge -t ${td}/${id}_tmp_corr $a
	${FSLDIR}/bin/fslmaths ${td}/${id}_tmp_corr -Tmean ${td}/${id}_mean
	${FSLDIR}/bin/imcp ${td}/${id}_mean ${wdir}/${id}_fbb 
else
	${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -f ${wdir}/${id}_struc.nii.gz -m ${src} -t s -o ${td}/${id}_movingToFixed_
	${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${src} -t ${td}/${id}_movingToFixed_0GenericAffine.mat -t ${td}/${id}_movingToFixed_1Warp.nii.gz -o ${wdir}/${id}_fbb.nii.gz
fi

if [ $debug = 0 ] ; then
    rm -rf ${td}
fi
