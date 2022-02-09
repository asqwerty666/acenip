#!/bin/sh
 
Usage() {                      
    echo ""                                                                                                                                                              
    echo "Usage: dti_bedtrack.sh  <project> <subject> <working dir>" 
    echo ""                                                                                                                                                              
    echo "You must have FSL installed in order to run this script"                                                                                                       
    echo ""                                                                                                                                                              
    exit 1                                                                                                                                                               
}                                                                                                                                                                        
 
[ "$3" = "" ] && Usage
debug=1
prj=$1
shift
pollo=$1
shift
w_dir=$1
shift

td=${w_dir}'/.tmp_'${pollo}
bd=${td}'/bedpostx'
list=${w_dir}'/../dti_track.seed'
if [ ! -d "$bd" ]; then                                                                                                                                                  
        mkdir $bd                                                                                                                                                        
fi 
echo "Copying files"
${FSLDIR}/bin/imcp ${w_dir}/${pollo}_dti_data ${bd}/data
${FSLDIR}/bin/imcp ${w_dir}/${pollo}_dti_brain_mask ${bd}/nodif_brain_mask
cp ${td}/bvecs ${bd}/bvecs
cp ${td}/bvals ${bd}/bvals
echo "Making bedpostx"
echo [`date`]
${FSLDIR}/bin/bedpostx_gpu ${bd}
echo "So far, so good"
echo [`date`]
echo "Getting aseg"
${PIPEDIR}/bin/get_aparc.sh ${prj} ${pollo} ${w_dir}
antsApplyTransforms -d 3 -i ${w_dir}/${pollo}_aseg.nii.gz -r ${td}/hifi_b0.nii.gz -t ${td}/${pollo}_epi_reg_ANTS.mat -n GenericLabel -o ${td}/${pollo}_aseg_warped.nii.gz
#WarpImageMultiTransform 3 ${w_dir}/${pollo}_aseg.nii.gz ${td}/${pollo}_aseg_warped.nii.gz -R ${td}/hifi_b0.nii.gz ${td}/${pollo}_dti_t1_b0Warp.nii.gz ${td}/${pollo}_dti_t1_b0Affine.txt
###########################################
######## Falta calcular las mascaras ######
###########################################
for x in `awk NF $list`; do
	${FSLDIR}/bin/fslmaths ${td}/${pollo}_aseg_warped -uthr ${x} -thr ${x} -div ${x} ${td}/${pollo}_mask_${x};
	echo "${td}/${pollo}_mask_${x}.nii.gz" >> ${td}/${pollo}_mask.list;
done;
###########################################		
echo "Doing probtrackx"
probtrackx2 --opd --forcedir -s ${bd}.bedpostX/merged -m ${w_dir}/${pollo}_dti_brain_mask -x ${td}/${pollo}_mask.list --dir=${td}/probtrack_out
rm ${td}/${pollo}_mask.list;
mv ${td}/probtrack_out ${w_dir}/${pollo}_probtrack_out
echo "Done"
echo [`date`]
