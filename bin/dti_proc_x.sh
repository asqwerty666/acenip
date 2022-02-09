#!/bin/sh

Usage() {
    echo ""
    echo "Usage: dti_proc_x.sh <project> <subject> <dwi> <t1w> <output_dir>"
    echo ""
    echo "run dti preprocessing (dtifit) over <input> image"
    echo "and place it as <name> and its results into <output_dir>"
    echo ""
    echo "You must have FSL installed in order to run this script"
    echo ""
    echo ""
    exit 1
}


[ "$5" = "" ] && Usage
debug=1
study=$1
shift
b_in=$1
shift
in=`${FSLDIR}/bin/remove_ext $1`
shift
t1=`${FSLDIR}/bin/remove_ext $1`
shift
out=$1
shift
td=${out}'/.tmp_'${b_in}
if [ ! -d "$out" ]; then
        mkdir $out
fi
if [ ! -d "$td" ]; then
	mkdir $td
fi

echo "DTI preproccessing begins ..."
echo [`date`]
echo
${FSLDIR}/bin/fslroi ${in} ${out}/${b_in}_dti_b0 0 1
echo "Copying files for ${b_in} to ${td}/"
echo
${FSLDIR}/bin/imcp ${in} ${td}/${b_in}
cp ${in}.bval ${td}/bvals
cp ${in}.bvec ${td}/bvecs
echo "Doing correction on ${td}/${b_in}"
echo
${FSLDIR}/bin/eddy_correct ${td}/${b_in} ${td}/data 0
echo "Doing BET on ${td}/data now"
echo
${FSLDIR}/bin/bet ${td}/data ${td}/nodif_brain -f 0.3 -g 0 -n -m 
echo "Running dtifit on ${td}/data"
echo
${FSLDIR}/bin/dtifit --data=${td}/data --out=${td}/dti --mask=${td}/nodif_brain_mask --bvecs=${td}/bvecs --bvals=${td}/bvals
echo "I will copy all output files to ${out}/${b_in}_XXXXX"
echo
for x in ${td}/dti*; do ${FSLDIR}/bin/imcp ${x} ${out}/${b_in}_$(basename $x); done;
${FSLDIR}/bin/imcp ${td}/nodif_brain_mask ${out}/${b_in}_nodif_brain_mask
${FSLDIR}/bin/imcp ${td}/data ${out}/${b_in}_data
echo "I need the T1 image"  
${FSLDIR}/bin/fslreorient2std ${t1} ${out}/${b_in}_t1_reoriented
echo "and brain extracted too"
$FSLDIR/bin/bet ${out}/${b_in}_t1_reoriented ${out}/${b_in}_t1_reoriented_brain
echo "Registering FA to FMRIB58"
${FSLDIR}/bin/flirt -ref ${FSLDIR}/data/standard/FMRIB58_FA_1mm.nii.gz -in ${out}/${b_in}_dti_FA.nii.gz -omat ${td}/${b_in}_dti_affine.mat
${FSLDIR}/bin/fnirt --in=${out}/${b_in}_dti_FA.nii.gz --aff=${td}/${b_in}_dti_affine.mat --cout=${td}/${b_in}_dti_warp --config=FA_2_FMRIB58_1mm
${FSLDIR}/bin/applywarp --ref=${FSLDIR}/data/standard/FMRIB58_FA_1mm.nii.gz --in=${out}/${b_in}_dti_FA.nii.gz --warp=${td}/${b_in}_dti_warp --out=${td}/${b_in}_fa_std
echo "Moving B0 to MNI space and making B0 mask"
${FSLDIR}/bin/applywarp --ref=${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz --in=${out}/${b_in}_dti_b0 --warp=${td}/${b_in}_dti_warp --out=${td}/${b_in}_b0_std
${FSLDIR}/bin/fslmaths ${td}/${b_in}_b0_std -bin ${td}/${b_in}_b0_std_mask
${FSLDIR}/bin/fslmaths ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz -mas ${td}/${b_in}_b0_std_mask.nii.gz ${td}/${b_in}_mni_masked
echo "Registering MNI choped template to Native Space now ...."
#ANTS 3 -m CC[${out}/${b_in}_t1_reoriented.nii.gz, ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz, 1, 4] -r Gauss[0,3] -t Elast[1.5] -i 30x20x10 -o ${td}/${b_in}_dti_mni_t1.nii.gz
#WarpImageMultiTransform 3 ${td}/${b_in}_mni_masked.nii.gz ${td}/mni_mask_warped_tmp.nii.gz -R ${out}/${b_in}_t1_reoriented.nii.gz ${td}/${b_in}_dti_mni_t1Warp.nii.gz ${td}/${b_in}_dti_mni_t1Affine.txt
antsRegistrationSyN.sh -d 3 -f ${out}/${b_in}_t1_reoriented.nii.gz -m ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz -o ${td}/${b_in}_dti_mni_t1_
antsApplyTransforms -d 3 -i ${td}/${b_in}_mni_masked.nii.gz -r ${out}/${b_in}_t1_reoriented.nii.gz -o ${td}/mni_mask_warped_tmp.nii.gz -t ${td}/${b_in}_dti_mni_t1_1Warp.nii.gz -t ${td}/${b_in}_dti_mni_t1_0GenericAffine.mat
echo "Calculating choped T1"
${FSLDIR}/bin/fslmaths ${out}/${b_in}_t1_reoriented.nii.gz -mas ${td}/mni_mask_warped_tmp.nii.gz ${td}/t1_mask_warped_tmp.nii.gz
echo "I get the extracted brain"
${FREESURFER_HOME}/bin/mri_vol2vol --mov ${SUBJECTS_DIR}/${study}_${b_in}/mri/brain.mgz --targ ${SUBJECTS_DIR}/${study}_${b_in}/mri/rawavg.mgz --regheader --o ${td}/${b_in}_tmp_brain_in_rawavg.mgz
${FREESURFER_HOME}/bin/mri_convert --in_type mgz --out_type nii ${td}/${b_in}_tmp_brain_in_rawavg.mgz ${td}/${b_in}_tmp_brain.nii.gz
${FSLDIR}/bin/fslreorient2std ${td}/${b_in}_tmp_brain ${out}/${b_in}_brain
echo "Calculating choped brain only"
${FSLDIR}/bin/fslmaths ${out}/${b_in}_brain.nii.gz -mas ${td}/mni_mask_warped_tmp.nii.gz ${td}/brain_mask_warped_tmp.nii.gz
########### THIS is the REAL DEAL ######################
echo "Registering choped T1 to B0"
#antsRegistrationSyN.sh -d 3 -f ${td}/t1_mask_warped_tmp.nii.gz -m ${out}/${b_in}_dti_b0.nii.gz -o ${out}/${b_in}_t1_dti_warp -t a -j 1
${FSLDIR}/bin/epi_reg --epi=${out}/${b_in}_data --t1=${td}/t1_mask_warped_tmp --t1brain=${td}/brain_mask_warped_tmp --out=${td}/${b_in}_tmp_diff2std
${FSLDIR}/bin/convert_xfm -omat ${td}/${b_in}_tmp_std2diff.mat -inverse ${td}/${b_in}_tmp_diff2std.mat
c3d_affine_tool -ref ${out}/${b_in}_dti_b0.nii.gz -src ${td}/t1_mask_warped_tmp.nii.gz ${td}/${b_in}_tmp_std2diff.mat -fsl2ras -oitk ${td}/${b_in}_epi_reg_ANTS.mat
antsApplyTransforms -d 3 -i ${td}/t1_mask_warped_tmp.nii.gz -r ${out}/${b_in}_dti_b0.nii.gz -t ${td}/${b_in}_epi_reg_ANTS.mat -o ${out}/${b_in}_t1_b0.nii.gz
#antsApplyTransforms -d 3 -i ${td}/${b_in}_mni_t1_warped.nii.gz -r ${td}/hifi_b0.nii.gz -t ${td}/${b_in}_epi_reg_ANTS.mat -o ${out}/${b_in}_mni_to_b0.nii.gz
########################################################
echo "Lets begin now"
########### Voy a mover el template MNI a B0 para chequear despues #############
########### aunque no es necesario para el calculo #############################
echo "Registering MNI template to T1"
#antsRegistrationSyN.sh -d 3 -f ${out}/${b_in}_t1_reoriented.nii.gz -m ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz -o ${td}/${b_in}_mni_t1_warp
antsApplyTransforms -d 3 -i ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz -r ${out}/${b_in}_t1_reoriented.nii.gz -t ${td}/${b_in}_dti_mni_t1_1Warp.nii.gz -t ${td}/${b_in}_dti_mni_t1_0GenericAffine.mat -o ${out}/${b_in}_mni_t1_warped.nii.gz
echo "Registering warped MNI to B0"
antsApplyTransforms -d 3 -i ${out}/${b_in}_mni_t1_warped.nii.gz -r ${out}/${b_in}_dti_b0.nii.gz -t ${td}/${b_in}_epi_reg_ANTS.mat -o ${out}/${b_in}_mni_to_b0.nii.gz
############ Ahora le toca a los atlas ####################
echo "Warping Atlases to B0"
antsApplyTransforms -d 3 -i ${FSLDIR}/data/atlases/JHU/JHU-ICBM-labels-1mm.nii.gz -r ${out}/${b_in}_t1_reoriented.nii.gz -t ${td}/${b_in}_dti_mni_t1_1Warp.nii.gz -t ${td}/${b_in}_dti_mni_t1_0GenericAffine.mat -n GenericLabel -o ${td}/${b_in}_JHU_labels_tmp.nii.gz
antsApplyTransforms -d 3 -i ${td}/${b_in}_JHU_labels_tmp.nii.gz -r ${out}/${b_in}_dti_b0.nii.gz -t ${td}/${b_in}_epi_reg_ANTS.mat -n GenericLabel -o ${out}/${b_in}_JHU_labels.nii.gz
antsApplyTransforms -d 3 -i ${FSLDIR}/data/atlases/JHU/JHU-ICBM-tracts-maxprob-thr25-1mm.nii.gz -r ${out}/${b_in}_t1_reoriented.nii.gz -t ${td}/${b_in}_dti_mni_t1_1Warp.nii.gz -t ${td}/${b_in}_dti_mni_t1_0GenericAffine.mat -n GenericLabel -o ${td}/${b_in}_JHU_tracts_tmp.nii.gz
antsApplyTransforms -d 3 -i ${td}/${b_in}_JHU_tracts_tmp.nii.gz -r ${out}/${b_in}_dti_b0.nii.gz -t ${td}/${b_in}_epi_reg_ANTS.mat -n GenericLabel -o ${out}/${b_in}_JHU_tracts.nii.gz
###########################################################
${FSLDIR}/bin/imcp ${out}/${b_in}_dti_b0 ${out}/${b_in}_hifi_b0

if [ $debug = 0 ] ; then
	echo "Removing temporary files"
	echo
	rm -rf ${td}
#	rm -rf ${out}/${b_in}_tmp_*
fi

exit 0
