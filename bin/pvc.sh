#!/bin/sh
subject=$1
shift
wdir=$1
shift

petpvc -i ${wdir}/${subject}_tau.nii.gz -m ${wdir}/${subject}_masks.nii.gz -o ${wdir}/${subject}_pvc.csv -p GTM -x 6.0 -y 6.0 -z 6.0
