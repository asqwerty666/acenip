#!/bin/sh
subject=$1
shift

tmp_dir=$1
shift

roi=cerebgm.ref
#Primero sacar el cerebelo de FS
if [ ! -f ${tmp_dir}/rois/register.dat ]; then 
	mkdir -p ${tmp_dir}/rois/;
	tkregister2 --mov $SUBJECTS_DIR/${subject}/mri/rawavg.mgz --noedit --s ${subject} --regheader --reg ${tmp_dir}/rois/register.dat;
	#tkregister2 --mov $SUBJECTS_DIR/${subject}/mri/nu.mgz --noedit --s ${subject} --regheader --reg ${tmp_dir}/rois/register.dat;
fi
if [ ! -f ${tmp_dir}/all_aseg.nii.gz ]; then
	mri_label2vol --seg $SUBJECTS_DIR/${subject}/mri/aparc+aseg.mgz --temp $SUBJECTS_DIR/${subject}/mri/rawavg.mgz --o ${tmp_dir}/all_aseg.nii.gz --reg ${tmp_dir}/rois/register.dat;
	#mri_label2vol --seg $SUBJECTS_DIR/${subject}/mri/aparc+aseg.mgz --temp $SUBJECTS_DIR/${subject}/mri/nu.mgz 
fi
mkdir ${tmp_dir}/rois/${roi%.ref};
for x in `cat ${PIPEDIR}/lib/tau/${roi}`; do 
	sleep 5;
	rlabel=$(echo ${x} | awk -F"," '{print $1}');
	nlabel=$(echo ${x} | awk -F"," '{print $2}');
	${FSLDIR}/bin/fslmaths ${tmp_dir}/all_aseg.nii.gz -uthr ${rlabel} -thr ${rlabel} -div ${rlabel} ${tmp_dir}/rois/${roi%.ref}/${nlabel}
done
a=$(for x in ${tmp_dir}/rois/${roi%.ref}/*.nii.gz; do echo "${x} -add "; done) 
a=$(echo ${a} | sed 's/\(.*\)-add$/\1/')
#echo ${a}
${FSLDIR}/bin/fslmaths ${a} ${tmp_dir}/rois/${roi%.ref}.nii.gz 
#Ahora sacar el mapa de cerebelo de SUIT
#${FREESURFER_HOME}/bin/mri_convert --in_type mgz --out_type nii ${SUBJECTS_DIR}/${subject}/mri/rawavg.mgz ${tmp_dir}/${subject}_tmp.nii.gz
#${FSLDIR}/bin/fslreorient2std ${tmp_dir}/${subject}_tmp ${tmp_dir}/${subject}_struc
#${ANTSPATH}/antsRegistrationSyNQuick.sh -d 3 -f ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz -m ${tmp_dir}/${subject}_struc.nii.gz -o ${tmp_dir}/structToMNI_ -t s
#${ANTSPATH}/antsApplyTransforms -d 3 -i ${PIPEDIR}/lib/tau/Cerebellum-MNIsegment.nii.gz -r ${tmp_dir}/${subject}_struc.nii.gz -t [${tmp_dir}/structToMNI_0GenericAffine.mat, 1] -t ${tmp_dir}/structToMNI_1InverseWarp.nii.gz -n GenericLabel -o ${tmp_dir}/CerebinNS.nii.gz
#Dejar solo a parte de abajo?
#mkdir ${tmp_dir}/rois/incsuit
#for x in `cat ${PIPEDIR}/lib/tau/incsuit.ref`; do
#	${FSLDIR}/bin/fslmaths ${tmp_dir}/CerebinNS.nii.gz -uthr ${x} -thr  ${x} -div ${x} ${tmp_dir}/rois/incsuit/${x};
#done
#a=$(for x in ${tmp_dir}/rois/incsuit/*.nii.gz; do echo "${x} -add "; done)
#a=$(echo ${a} | sed 's/\(.*\)-add$/\1/')
#${FSLDIR}/bin/fslmaths ${a} ${tmp_dir}/rois/incsuit.nii.gz
#${FSLDIR}/bin/fslmaths ${tmp_dir}/rois/incsuit.nii.gz -kernel gauss 3.4 -fmean ${tmp_dir}/rois/incsuit_smooth.nii.gz 
#Excluir la parte de arriba correctamente
#mkdir ${tmp_dir}/rois/excsuit
#for x in `cat ${PIPEDIR}/lib/tau/excsuit.ref`; do
#	${FSLDIR}/bin/fslmaths ${tmp_dir}/CerebinNS.nii.gz -uthr ${x} -thr  ${x} -div ${x} ${tmp_dir}/rois/excsuit/${x};
#	sleep 2;
#done
#a=$(for x in ${tmp_dir}/rois/excsuit/*.nii.gz; do echo "${x} -add "; done)
#a=$(echo ${a} | sed 's/\(.*\)-add$/\1/')
#${FSLDIR}/bin/fslmaths ${a} ${tmp_dir}/rois/excsuit.nii.gz
#${FSLDIR}/bin/fslmaths ${tmp_dir}/rois/excsuit.nii.gz -kernel gauss 3.4 -fmean ${tmp_dir}/rois/excsuit_smooth.nii.gz
#${FSLDIR}/bin/fslmaths ${tmp_dir}/rois/incsuit_smooth.nii.gz -sub ${tmp_dir}/rois/excsuit_smooth.nii.gz -bin ${tmp_dir}/rois/icereb_mask.nii.gz
#${FSLDIR}/bin/fslmaths ${tmp_dir}/rois/${roi%.ref} -mas ${tmp_dir}/rois/icereb_mask.nii.gz ${tmp_dir}/rois/icgm.nii.gz 
