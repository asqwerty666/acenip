#!/bin/sh

id=$1
shift

dir=$1
shift

lut=$1
shift

debug=0

${FSLDIR}/bin/fslmaths ${dir}/${id}_aseg.nii.gz -uthr ${lut} -thr ${lut} -div ${lut} ${dir}/${id}_${lut}.nii.gz
