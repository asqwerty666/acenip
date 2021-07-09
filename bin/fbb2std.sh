#!/bin/sh

id=$1
shift

wdir=$1
shift

echo "I need the FBB image at MNI space"                                                                                                                                               
ANTS 3 -m CC[${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz, ${wdir}/${id}_struc.nii.gz, 1, 4] -r Gauss[0,3] -t Elast[1.5] -i 30x20x10 -o ${wdir}/${id}_fbb_t1_mni.nii.gz
sleep 1 #puto nas que me tiene hasta los cojones
WarpImageMultiTransform 3 ${wdir}/${id}_fbb.nii.gz ${wdir}/${id}_fbb_mni.nii.gz -R ${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz ${wdir}/${id}_fbb_t1_mniWarp.nii.gz ${wdir}/${id}_fbb_t1_mniAffine.txt

