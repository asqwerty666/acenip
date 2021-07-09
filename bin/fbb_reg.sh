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
		#${ANTS_PATH}/ANTS 3 -m CC[${wdir}/${id}_struc.nii.gz, ${items[$i]}, 1, 4] -r Gauss[0,3] -t Elast[1.5] -i 30x20x10 -o ${items[$i]%.nii.gz}_movingToFixed_
		#sleep 2 # porque el NAS es una puta mierda
		#${ANTS_PATH}/WarpImageMultiTransform 3 ${items[$i]} ${items[$i]%.nii.gz}_reg -R ${wdir}/${id}_struc.nii.gz ${items[$i]%.nii.gz}_movingToFixed_Warp.nii.gz ${items[$i]%.nii.gz}_movingToFixed_Affine.txt
		# Y aqui abajo las moderneces
		${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -f ${wdir}/${id}_struc.nii.gz -m ${items[$i]} -t a -o ${items[$i]%.nii.gz}_movingToFixed_ 
		# Apply no lineal (s)
		#${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${items[$i]} -t ${items[$i]%.nii.gz}_movingToFixed_0GenericAffine.mat -t ${items[$i]%.nii.gz}_movingToFixed_1Warp.nii.gz -o ${items[$i]%.nii.gz}_reg.nii.gz
		# Apply lineal (a)
		${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${items[$i]} -t ${items[$i]%.nii.gz}_movingToFixed_0GenericAffine.mat -o ${items[$i]%.nii.gz}_reg.nii.gz
		#y con flirt, pa q esten todos
		#${FSLDIR}/bin/flirt -ref ${wdir}/${id}_struc -in ${items[$i]} -omat ${items[$i]%.nii.gz}_pet2struc.mat -out ${items[$i]%.nii.gz}_reg
		${FSLDIR}/bin/imcp ${items[$i]%.nii.gz}_reg ${wdir}/ ;
	done
	a=`for i in ${!items[*]}; do echo " ${items[$i]%.nii.gz}_reg "; done`
	${FSLDIR}/bin/fslmerge -t ${td}/${id}_tmp_corr $a
	#${FSLDIR}/bin/mcflirt -in ${td}/${id}_tmp_mvc -out ${td}/${id}_tmp_corr
	#${FSLDIR}/bin/fslmaths ${td}/${id}_tmp_mvc -Tmean -s 1.274 ${td}/${id}_mean
	${FSLDIR}/bin/fslmaths ${td}/${id}_tmp_corr -Tmean ${td}/${id}_mean
	#${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -f ${wdir}/${id}_struc.nii.gz -m ${td}/${id}_mean.nii.gz -t a -o ${td}/${id}_movingToFixed_ 
	#${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${td}/${id}_mean.nii.gz -t ${td}/${id}_movingToFixed_0GenericAffine.mat -t ${td}/${id}_movingToFixed_1Warp.nii.gz -o ${wdir}/${id}_fbb.nii.gz
	#${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${td}/${id}_mean.nii.gz -t ${td}/${id}_movingToFixed_0GenericAffine.mat -o ${wdir}/${id}_fbb.nii.gz
	${FSLDIR}/bin/imcp ${td}/${id}_mean ${wdir}/${id}_fbb 
else
	#${ANTS_PATH}/ANTS 3 -m CC[${wdir}/${id}_struc.nii.gz, ${src}, 1, 4] -r Gauss[0,3] -t Elast[1.5] -i 30x20x10 -o ${td}/${id}_movingToFixed_
	#sleep 2 # porque el NAS es una puta mierda
	#${ANTS_PATH}/WarpImageMultiTransform 3 ${src} ${wdir}/${id}_fbb.nii.gz -R ${wdir}/${id}_struc.nii.gz ${td}/${id}_movingToFixed_Warp.nii.gz ${td}/${id}_movingToFixed_Affine.txt
	${ANTS_PATH}/antsRegistrationSyNQuick.sh -d 3 -f ${wdir}/${id}_struc.nii.gz -m ${src} -t s -o ${td}/${id}_movingToFixed_
	${ANTS_PATH}/antsApplyTransforms -d 3 -r ${wdir}/${id}_struc.nii.gz -i ${src} -t ${td}/${id}_movingToFixed_0GenericAffine.mat -t ${td}/${id}_movingToFixed_1Warp.nii.gz -o ${wdir}/${id}_fbb.nii.gz
	#${FSLDIR}/bin/mcflirt -in ${items[0]%.nii.gz}_reg -out ${wdir}/${id}_fbb
        #${FSLDIR}/bin/fslmaths ${items[0]%.nii.gz}_reg -s 1.27 ${wdir}/${id}_fbb
	#${FSLDIR}/bin/imcp ${items[0]%.nii.gz}_reg ${wdir}/${id}_fbb
fi

if [ $debug = 0 ] ; then
    rm -rf ${td}
fi
