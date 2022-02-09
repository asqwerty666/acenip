#!/bin/sh 

Usage() {  
    echo "" 
    echo "Usage: dti_proc_epi.sh  <study> <subject> <dwi> <dwi_pa> <T1> <output_dir>"  
    echo ""  
    echo "You must have FSL installed in order to run this script" 
    echo "" 
    exit 1 
} 
 
[ "$6" = "" ] && Usage 
debug=1
study=$1
shift
b_in=$1
shift  
in=`${FSLDIR}/bin/remove_ext $1` 
shift
p2a=`${FSLDIR}/bin/remove_ext $1`
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
echo "DTI preproccessing begins on ${b_in} ..." 
echo [`date`] 
echo 
${FSLDIR}/bin/fslroi $in ${td}/a2p_b0 0 1
echo "Preparing topup"
${FSLDIR}/bin/fslmerge -t ${td}/a2p_p2a_b0 ${td}/a2p_b0 ${p2a}
echo "Running topup"
${FSLDIR}/bin/topup --imain=${td}/a2p_p2a_b0 --datain=${out}/../acqparams.txt --out=${td}/topup_results --iout=${td}/hifi_b0
${FSLDIR}/bin/fslmaths ${td}/hifi_b0 -Tmean ${td}/hifi_b0
${FSLDIR}/bin/bet ${td}/hifi_b0 ${td}/hifi_b0_brain -m
echo "Copying files for ${b_in} to ${td}/"  
echo  
cp ${in}.bval ${td}/bvals
cp ${in}.bvec ${td}/bvecs 
echo "Doing correction on ${td}/${b_in}_hifi"  
echo [`date`]
echo  
${FSLDIR}/bin/eddy_cuda --imain=${in} --mask=${td}/hifi_b0_brain --acqp=${out}/../acqparams.txt --index=${out}/../dti_index.txt --bvecs=${td}/bvecs --bvals=${td}/bvals --topup=${td}/topup_results --out=${td}/data 
echo "Running dtifit on ${td}/data" 
echo [`date`]
echo 
${FSLDIR}/bin/dtifit --data=${td}/data --out=${td}/dti --mask=${td}/hifi_b0_brain --bvecs=${td}/bvecs --bvals=${td}/bvals                                                
echo "I will copy all output files to ${out}/${b_in}_XXXXX" 
echo  
for x in ${td}/dti*; do ${FSLDIR}/bin/imcp ${x} ${out}/${b_in}_$(basename $x); done; 
${FSLDIR}/bin/imcp ${td}/hifi_b0_brain ${out}/${b_in}_dti_brain_mask  
${FSLDIR}/bin/imcp ${td}/data ${out}/${b_in}_dti_data  
echo "I need the T1 image"  
${FSLDIR}/bin/fslreorient2std ${t1} ${out}/${b_in}_t1_reoriented  
echo "I get the extracted brain"
${FREESURFER_HOME}/bin/mri_vol2vol --mov ${SUBJECTS_DIR}/${study}_${b_in}/mri/brain.mgz --targ ${SUBJECTS_DIR}/${study}_${b_in}/mri/rawavg.mgz --regheader --o ${td}/${b_in}_tmp_brain_in_rawavg.mgz
${FREESURFER_HOME}/bin/mri_convert --in_type mgz --out_type nii ${td}/${b_in}_tmp_brain_in_rawavg.mgz ${td}/${b_in}_tmp_brain.nii.gz
${FSLDIR}/bin/fslreorient2std ${td}/${b_in}_tmp_brain ${out}/${b_in}_brain
echo "Calculating transformation from MNI to T1"
echo [`date`]
echo
antsRegistrationSyN.sh -d 3 -f ${out}/${b_in}_t1_reoriented.nii.gz -m ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz -o ${td}/${b_in}_mni_t1_warp
antsApplyTransforms -d 3 -i ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz -r ${out}/${b_in}_t1_reoriented.nii.gz -t ${td}/${b_in}_mni_t1_warp1Warp.nii.gz -t ${td}/${b_in}_mni_t1_warp0GenericAffine.mat -o ${td}/${b_in}_mni_t1_warped.nii.gz
echo "Calculating transformation from T1 to B0"                                                       
echo [`date`]
echo
${FSLDIR}/bin/epi_reg --epi=${out}/${b_in}_dti_data --t1=${out}/${b_in}_t1_reoriented --t1brain=${out}/${b_in}_brain --out=${td}/${b_in}_tmp_diff2std
${FSLDIR}/bin/convert_xfm -omat ${td}/${b_in}_tmp_std2diff.mat -inverse ${td}/${b_in}_tmp_diff2std.mat
c3d_affine_tool -ref ${td}/hifi_b0.nii.gz -src ${out}/${b_in}_t1_reoriented.nii.gz ${td}/${b_in}_tmp_std2diff.mat -fsl2ras -oitk ${td}/${b_in}_epi_reg_ANTS.mat
antsApplyTransforms -d 3 -i ${out}/${b_in}_t1_reoriented.nii.gz -r ${td}/hifi_b0.nii.gz -t ${td}/${b_in}_epi_reg_ANTS.mat -o ${out}/${b_in}_t1_b0.nii.gz
antsApplyTransforms -d 3 -i ${td}/${b_in}_mni_t1_warped.nii.gz -r ${td}/hifi_b0.nii.gz -t ${td}/${b_in}_epi_reg_ANTS.mat -o ${out}/${b_in}_mni_to_b0.nii.gz
echo "Applying transformations to JHU Atlas (ICBM-labels)"
antsApplyTransforms -d 3 -i ${FSLDIR}/data/atlases/JHU/JHU-ICBM-labels-1mm.nii.gz -r ${out}/${b_in}_t1_reoriented.nii.gz -t ${td}/${b_in}_mni_t1_warp1Warp.nii.gz -t ${td}/${b_in}_mni_t1_warp0GenericAffine.mat -n GenericLabel -o ${td}/${b_in}_JHU_labels_tmp.nii.gz
antsApplyTransforms -d 3 -i ${td}/${b_in}_JHU_labels_tmp.nii.gz -r ${td}/hifi_b0.nii.gz -t ${td}/${b_in}_epi_reg_ANTS.mat -n GenericLabel -o ${out}/${b_in}_JHU_labels.nii.gz
echo "Applying transformations to JHU Atlas (ICBM-tracts)"
antsApplyTransforms -d 3 -i ${FSLDIR}/data/atlases/JHU/JHU-ICBM-tracts-maxprob-thr25-1mm.nii.gz -r ${out}/${b_in}_t1_reoriented.nii.gz -t ${td}/${b_in}_mni_t1_warp1Warp.nii.gz -t ${td}/${b_in}_mni_t1_warp0GenericAffine.mat -n GenericLabel -o ${td}/${b_in}_JHU_tracts_tmp.nii.gz
antsApplyTransforms -d 3 -i ${td}/${b_in}_JHU_tracts_tmp.nii.gz -r ${td}/hifi_b0.nii.gz -t ${td}/${b_in}_epi_reg_ANTS.mat -n GenericLabel -o ${out}/${b_in}_JHU_tracts.nii.gz
${FSLDIR}/bin/imcp ${td}/hifi_b0 ${out}/${b_in}_hifi_b0
echo "Game over :-P"
echo [`date`]
exit 0

