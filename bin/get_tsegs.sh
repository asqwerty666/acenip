#!/bin/sh
subject=$1
shift

tmp_dir=$1
shift

roifile=$1
shift

if [ ! -f ${tmp_dir}/fsrois/register.dat ]; then 
	mkdir -p ${tmp_dir}/fsrois/;
	tkregister2 --mov $SUBJECTS_DIR/${subject}/mri/rawavg.mgz --noedit --s ${subject} --regheader --reg ${tmp_dir}/fsrois/register.dat;
	sleep 5;
fi
if [ ! -f ${tmp_dir}/all_aseg.nii.gz ]; then
	mri_label2vol --seg $SUBJECTS_DIR/${subject}/mri/aparc+aseg.mgz --temp $SUBJECTS_DIR/${subject}/mri/rawavg.mgz --o ${tmp_dir}/all_aseg.nii.gz --reg ${tmp_dir}/fsrois/register.dat;
	sleep 5;
fi
for x in `cat ${roifile}`; do 
	sleep 5;
	rlabel=$(echo ${x} | awk -F"," '{print $1}');
	nlabel=$(echo ${x} | awk -F"," '{print $2}');
	${FSLDIR}/bin/fslmaths ${tmp_dir}/all_aseg.nii.gz -uthr ${rlabel} -thr ${rlabel} -div ${rlabel} ${tmp_dir}/fsrois/${nlabel};
	echo "${nlabel} --> ${rlabel}"
	sleep 2
done
a=$(for x in ${tmp_dir}/fsrois/*.nii.gz; do echo "${x} "; done) 
#a=$(echo ${a} | sed 's/\(.*\)-add$/\1/')
echo ${a}
${FSLDIR}/bin/fslmerge -t ${tmp_dir}/fsrois/segrois.nii.gz ${a} 
echo "That's all folks!"
