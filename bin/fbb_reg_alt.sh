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
		# Esto es para probar porque las moderneces de ANTs son inestables
		${ANTS_PATH}/ANTS 3 -m CC[${wdir}/${id}_struc.nii.gz, ${items[$i]}, 1, 4] -r Gauss[0,3] -t Elast[1.5] -i 30x20x10 -o ${items[$i]%.nii.gz}_movingToFixed_
		sleep 2 # porque el NAS es una puta mierda
		${ANTS_PATH}/WarpImageMultiTransform 3 ${items[$i]} ${items[$i]%.nii.gz}_reg -R ${wdir}/${id}_struc.nii.gz ${items[$i]%.nii.gz}_movingToFixed_Warp.nii.gz ${items[$i]%.nii.gz}_movingToFixed_Affine.txt
		${FSLDIR}/bin/imcp ${items[$i]%.nii.gz}_reg ${wdir}/ ;
	done
	a=`for i in ${!items[*]}; do echo " ${items[$i]%.nii.gz}_reg "; done`
	${FSLDIR}/bin/fslmerge -t ${td}/${id}_tmp_corr $a
	${FSLDIR}/bin/fslmaths ${td}/${id}_tmp_corr -Tmean ${td}/${id}_mean
	${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -f ${wdir}/${id}_struc.nii.gz -m ${td}/${id}_mean.nii.gz -t a -o ${td}/${id}_movingToFixed_ 
	${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${td}/${id}_mean.nii.gz -t ${td}/${id}_movingToFixed_0GenericAffine.mat -o ${wdir}/${id}_fbb.nii.gz
else
	${ANTS_PATH}/ANTS 3 -m CC[${wdir}/${id}_struc.nii.gz, ${src}, 1, 4] -r Gauss[0,3] -t Elast[1.5] -i 30x20x10 -o ${td}/${id}_movingToFixed_
	sleep 2 # porque el NAS es una puta mierda
	${ANTS_PATH}/WarpImageMultiTransform 3 ${src} ${wdir}/${id}_fbb.nii.gz -R ${wdir}/${id}_struc.nii.gz ${td}/${id}_movingToFixed_Warp.nii.gz ${td}/${id}_movingToFixed_Affine.txt
fi

if [ $debug = 0 ] ; then
    rm -rf ${td}
fi
