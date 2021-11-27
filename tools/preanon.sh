#!/bin/bash 

src=$1
shift

tdir=$(mktemp -t -d dcm.XXXXXXXX)
outdir=$(mktemp -t -d anon.XXXXXX)
unzip "${src}" -d ${tdir}
hfile=$(find ${tdir} -type f | head -n 1)
patid=$(dckey -k "PatientID" "${hfile}" 2>&1 | sed 's/[[:space:]]//g')
sdate=$(dckey -k "AcquisitionDate" "${hfile}" 2>&1 | sed 's/[[:space:]]//g')
nhc=$(dckey -k "(0x0010,0x4000)" "${hfile}" 2>&1 | awk -F"NHC " '{print $2}')
dcanon ${tdir} ${outdir}/${nhc}/${sdate} nomove ${nhc} ${patid} 
xnatapic upload_dicom --project_id unidad --subject_id ${nhc} --pipelines ${outdir}/${nhc}/${sdate}
rm -rf ${tdir}
rm -rf ${outdir}
sqlcmd -U osotolongo -P Fundacio21 -S 172.26.2.161 -s "," -W -Q "SELECT xapellido1, xapellido2, xnombre, his_interno FROM [UNIT4_DATA].[imp].[vh_pac_gral] WHERE his_interno = '"${nhc}"';"
