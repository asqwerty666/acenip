#!/bin/sh
subject=$1
shift

tmp_dir=$1
shift

roi=$1
shift

if [ ! -f ${tmp_dir}/rois/register.dat ]; then 
	mkdir -p ${tmp_dir}/rois/;
	tkregister2 --mov $SUBJECTS_DIR/${subject}/mri/rawavg.mgz --noedit --s ${subject} --regheader --reg ${tmp_dir}/rois/register.dat;
	sleep 5;
fi
if [ ! -f ${tmp_dir}/all_aseg.nii.gz ]; then
	mri_label2vol --seg $SUBJECTS_DIR/${subject}/mri/aparc+aseg.mgz --temp $SUBJECTS_DIR/${subject}/mri/rawavg.mgz --o ${tmp_dir}/all_aseg.nii.gz --reg ${tmp_dir}/rois/register.dat;
	sleep 5;
fi
mkdir ${tmp_dir}/rois/${roi};
for x in `cat ${PIPEDIR}/lib/tau/${roi}.roi`; do 
	sleep 5;
	rlabel=$(echo ${x} | awk -F"," '{print $1}');
	nlabel=$(echo ${x} | awk -F"," '{print $2}');
	${FSLDIR}/bin/fslmaths ${tmp_dir}/all_aseg.nii.gz -uthr ${rlabel} -thr ${rlabel} -div ${rlabel} ${tmp_dir}/rois/${roi}/${nlabel};
done
a=$(for x in ${tmp_dir}/rois/${roi}/*.nii.gz; do echo "${x} -add "; done) 
a=$(echo ${a} | sed 's/\(.*\)-add$/\1/')
#echo ${a}
${FSLDIR}/bin/fslmaths ${a} ${tmp_dir}/rois/${roi} 
