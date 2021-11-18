#!/bin/bash 

src=$1
shift
#outdir=$1
#shift
interno=$1
shift

tdir=$(mktemp -t -d dcm.XXXXXXXX)
outdir=$(mktemp -t -d anon.XXXXXX)
unzip "${src}" -d ${tdir}
hfile=$(find ${tdir} -type f | head -n 1)
patid=$(dckey -k "PatientID" "${hfile}" 2>&1 | sed 's/[[:space:]]//g')
sdate=$(dckey -k "AcquisitionDate" "${hfile}" 2>&1 | sed 's/[[:space:]]//g')
dcanon ${tdir} ${outdir}/${interno}/${sdate} nomove ${interno} ${patid} 
#xnatapic upload_dicom --project_id unidad --subject_id 20211475 /old_nas/MRIFACE/20211475/20211029 
xnatapic upload_dicom --project_id unidad --subject_id ${interno} --pipelines ${outdir}/${interno}/${sdate}
#find ${tdir} -type f | while read line; do
#	xe=$(echo ${line} | sed 's/[[:space:]]/_/g')
#	#echo ${xe}
#	nf=$(basename ${xe})
#	fd=$(echo "${nf}" | sed s"/.*\.MR/${patid}.MR/")
#	mv "$line" ${patid}/${fd}
#done 
rm -rf ${tdir}
rm -rf ${outdir}
