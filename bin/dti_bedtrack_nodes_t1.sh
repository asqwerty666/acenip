#!/bin/sh

Usage() { 
    echo "" 
    echo "Usage: dti_bedtrack.sh  <project> <subject> <working dir> <network dir>"
    echo "" 
    echo "You must have FSL installed in order to run this script"
    echo ""
    exit 1
} 

[ "$4" = "" ] && Usage
debug=1
prj=$1
shift
pollo=$1
shift
w_dir=$1
shift
net_dir=$1
shift
td=${w_dir}'/.tmp_'${pollo}
bd=${td}'/bedpostx'
list=${w_dir}'/../dti_track.seed'
if [ ! -d "$bd" ]; then
mkdir $bd 
fi 
echo "Copying files"
${FSLDIR}/bin/imcp ${td}/data ${bd}/data
${FSLDIR}/bin/imcp ${td}/nodif_brain_mask ${bd}/nodif_brain_mask
cp ${td}/bvecs ${bd}/bvecs
cp ${td}/bvals ${bd}/bvals
echo "Making bedpostx"
echo [`date`]
${FSLDIR}/bin/bedpostx_gpu ${bd}
echo "So far, so good"
echo [`date`]
###########################################
echo "Getting nodes and making masks"
for x in `find ${net_dir} -name "*.nii"`; do
	node=`${FSLDIR}/bin/remove_ext $(basename ${x})`;
#		WarpImageMultiTransform 3 ${x} ${td}/${node}_warped.nii.gz -R ${w_dir}/${pollo}_t1_reoriented.nii.gz ${td}/${pollo}_dti_mni_t1Warp.nii.gz ${td}/${pollo}_dti_mni_t1Affine.txt;
#		WarpImageMultiTransform 3 ${td}/${node}_warped.nii.gz ${td}/${pollo}_${node}.nii.gz -R ${td}/hifi_b0.nii.gz ${td}/${pollo}_dti_t1_b0Warp.nii.gz ${td}/${pollo}_dti_t1_b0Affine.txt;
	dim1=$(fslinfo ${x} | grep "^dim1" | awk {'print $2'});
	if [ ${dim1} = 91 ]; then
		if [ ! -e ${td}/${pollo}_dti_mni_t121Warp.nii.gz ]; then
			antsRegistrationSyNQuick.sh -d 3 -f ${w_dir}/${pollo}_t1_reoriented.nii.gz -m ${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz -o ${td}/${pollo}_dti_mni_t12 -t s;
		fi;
		antsApplyTransforms -d 3 -i ${x} -r ${w_dir}/${pollo}_t1_reoriented.nii.gz -t ${td}/${pollo}_dti_mni_t121Warp.nii.gz -t ${td}/${pollo}_dti_mni_t120GenericAffine.mat -o ${td}/${node}_warped.nii.gz;
	else		
		antsApplyTransforms -d 3 -i ${x} -r ${w_dir}/${pollo}_t1_reoriented.nii.gz -t ${td}/${pollo}_dti_mni_t1_1Warp.nii.gz -t ${td}/${pollo}_dti_mni_t1_0GenericAffine.mat -o ${td}/${node}_warped.nii.gz;
	fi;
	antsApplyTransforms -d 3 -i ${td}/${node}_warped.nii.gz -r ${w_dir}/${pollo}_dti_b0.nii.gz -t ${td}/${pollo}_epi_reg_ANTS.mat -o ${td}/${pollo}_${node}.nii.gz

	echo "${td}/${pollo}_${node}.nii.gz" >> ${td}/${pollo}_mask.list;
done;
###########################################		
echo "Doing probtrackx"
${FSLDIR}/bin/probtrackx2 --opd --forcedir -s ${bd}.bedpostX/merged -m ${td}/nodif_brain_mask -x ${td}/${pollo}_mask.list --dir=${td}/probtrack_out
rm ${td}/${pollo}_mask.list;
mv ${td}/probtrack_out ${w_dir}/${pollo}_probtrack_out
echo "Done"
echo [`date`]
