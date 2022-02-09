#!/bin/sh
subject=$1
shift

tmp_dir=$1
shift

mri_annotation2label --subject ${subject} --hemi lh --outdir $SUBJECTS_DIR/${subject}/labels
tkregister2 --mov $SUBJECTS_DIR/${subject}/mri/rawavg.mgz --noedit --s ${subject} --regheader --reg ${tmp_dir}/lh.register.dat
mri_annotation2label --subject ${subject} --hemi rh --outdir $SUBJECTS_DIR/${subject}/labels
tkregister2 --mov $SUBJECTS_DIR/${subject}/mri/rawavg.mgz --noedit --s ${subject} --regheader --reg ${tmp_dir}/rh.register.dat
