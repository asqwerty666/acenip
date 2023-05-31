#!/bin/bash 

src=$1
shift
nhc=$1
shift

if [ -z ${nhc} ]; then 
	./get_nhc.pl "${src}"
else
	tdir=$(mktemp -t -d dcm.XXXXXXXX)
	outdir=$(mktemp -t -d anon.XXXXXX)
	if [ -f "${src}" ]; then
		unzip "${src}" -d ${tdir}
	fi
	if [ -d "${src}" ]; then
		cp -r "${src}" ${tdir}
	fi
	hfile=$(find ${tdir} -type f | head -n 1)
	patid=$(dckey -k "StudyID" "${hfile}" 2>&1 | sed 's/[[:space:]]//g')
	sdate=$(dckey -k "StudyDate" "${hfile}" 2>&1 | sed 's/[[:space:]]//g')
	echo "${outdir}/${nhc}/${sdate}"
	dcanon ${tdir} "${outdir}/${nhc}/${sdate}" nomove ${nhc} ${patid} 
	xnatapic upload_dicom --project_id unidad --subject_id ${nhc} --pipelines ${outdir}/${nhc}/${sdate}
	# Este añade dob y gender 
	./update_sbj.pl -x unidad -i ${nhc}
	#echo "${tdir} ${outdir}"
	rm -rf ${tdir}
	rm -rf ${outdir}
	./nhc2data.pl ${nhc}
fi
