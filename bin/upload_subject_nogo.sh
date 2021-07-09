#!/bin/bash

PROY=$1
shift
SUBJECT=$1
shift
DIR=$1
shift

XNAT=http://detritus.fundacioace.com:8088
USER=osotolongo:kaponko

TMP_PRO=$(mktemp)
TMP_VAL=$(mktemp)
TMP_SCS=$(mktemp -d)
#	rm $TMP_SCS
#	mkdir $TMP_SCS

#Tipos de estudios
cat > $TMP_PRO <<.EOF
ep2d_bold_p2_resting_state
ep2d_fid_basic_bold_p2_AP
ep2d_fid_basic_bold_p2_PA
asl_3d_tra_iso_3.0_highres
DTIep2d_diff_mddw_48dir_p3_AP
DTIep2d_diff_mddw_4b0_PA
t1_mprage_sag_p2_iso
t2_space_dark-fluid_sag_p2_iso
.EOF

#Archivos de la misma serie ($4 único), con fechas y descripciones, filtrados por tipo de estudio
for x in $( ls "$DIR" | awk -F"." '{print $4}' | uniq ); do
	h=$(ls "$DIR" | grep '^[A-Z0-9_]\+\.[A-Z0-9_]\+\.[A-Z0-9_]\+\.'$x'\.' | head -n 1)
	d=$(dckey -k "AcquisitionDate" "$DIR/$h" 2>&1 | grep -v Error) && sd=$(dckey -k "SeriesDescription" "$DIR/$h" 2>&1 | grep -v Error | sed 's/[ \t]*$//') && sn=$(dckey -k "SequenceName" "$DIR/$h" 2>&1 | grep -v Error | sed 's/^*//;s/#.*//') && echo "$x,$sd,$sn"
done | grep -w -f $TMP_PRO > $TMP_VAL
# salida: series de archivos válidas
#Todos los archivos en el directorio son de la misma fecha y paciente
#DATE=$(dckey -k "AcquisitionDate" $(ls "$DIR" | head -n 1) 2>&1) # error prone
#PTID=$(dckey -k "PatientID" $(ls "$DIR" | head -n 1) 2>&1 | sed 's/^[ \t]*$//') # error prone

#Guardar los archivos de cada serie en un TAR.GZ -> voy a comentarlo porque abajo se hacen de nuevo
#for x in $(awk -F"," '{print $1}' $TMP_VAL); do
	#NOTA: usamos el truco de conversión de nombre del tar para no tener que copiar datos
#	tar czvf $TMP_SCS/$x.tar.gz --transform='s/^"$DIR"\//"$x"\//' -C "$DIR" $(ls "$DIR" | grep '^[A-Z0-9_]\+\.[A-Z0-9_]\+\.[A-Z0-9_]\+\.'$x'\.'| sed ':a;N;$!ba;s/\n/ /g')
#done

#Todos los archivos en el directorio son de la misma fecha y paciente
DATE=$(dckey -k "AcquisitionDate" $(ls "$DIR"/*$(head -n 1 $TMP_VAL | awk -F"," '{print $1}')*| head -n 1) 2>&1)
PTID=$(dckey -k "PatientID" $(ls "$DIR"/*$(head -n 1 $TMP_VAL | awk -F"," '{print $1}')*| head -n 1) 2>&1 | sed 's/[ \t]$//g')

#cat $TMP_VAL
#rm -rf  $TMP_PRO $TMP_VAL $TMP_SCS
#exit

#Guardar los archivos de cada serie en un TAR.GZ -> No entiendo porque se hace de nuevo esto, y distinto?
for x in $(awk -F"," '{print $1}' $TMP_VAL); do
	#NOTA: usamos el truco de conversión de nombre del tar para no tener que copiar datos
	tar czf $TMP_SCS/$x.tar.gz --transform='s/^"$DIR"\//"$x"\//' $(ls "$DIR"/* | grep '\/[A-Z0-9_]\+\.[A-Z0-9_]\+\.[A-Z0-9_]\+\.'$x'\.'| sed ':a;N;$!ba;s/\n/ /g')
done

#Crear el proyecto, el paciente y el experimento
curl -X PUT -u ${USER} "${XNAT}"/data/projects/"$PROY"
curl -X PUT -u $USER "$XNAT"/data/projects/"$PROY"/subjects/"$SUBJECT"
curl -X PUT -u $USER "$XNAT"/data/projects/"$PROY"/subjects/"$SUBJECT"/experiments/"$PTID"?xnat:mrSessionData/date="$DATE"

#Cargar los datos de las series (para ahorrar espacio en disco, se podría integrar aquí la creación de los tar.gz) -> no vale la pena :-P
cat $TMP_VAL | while read l ; do
	x=$(echo "$l" | awk -F"," '{print $1}')
	TAG=$(echo "$l" | awk -F"," '{print $2}')
	NAME=$(echo "$l" | awk -F"," '{print $3}')
	#crear la serie de tipo mrScanData
	#curl -X PUT -u $USER "$XNAT/data/projects/$PROY/subjects/$SUBJECT/experiments/$PTID/scans/$x?xsiType=xnat:mrScanData"
	#poner la descripción de la serie (el TAG)
	#curl -X PUT -u $USER "${XNAT}/data/projects/${PROY}/subjects/${SUBJECT}/experiments/${PTID}/scans/${x}?xsiType=xnat:mrScanData&xnat:mrScanData/series_description=${TAG}&xnat:imageScanData/quality=usable&xnat:imageScanData/type=${NAME}"
	#definir un recurso DICOM
	#curl -X PUT -u $USER "$XNAT/data/projects/$PROY/subjects/$SUBJECT/experiments/$PTID/scans/$x/resources/DICOM/?format=DICOM"
	#cargar los DICOM en los TAR.GZ (esto, parece que no funciona en la parte del curl)
	#curl -X PUT -u $USER "$XNAT/data/projects/$PROY/subjects/$SUBJECT/experiments/$PTID/scans/$x/resources/DICOM/files?extract=true" -F "file.tar.gz=@"$TMP_SCS"/"$x".tar.gz"
	curl -X PUT -u ${USER} "${XNAT}/data/services/import?import-handler=gradual-DICOM&dest=/archive/projects/${PROY}/subjects/${SUBJECT}/experiments/${PTID}" -F "file.tar.gz=@"$TMP_SCS"/"$x".tar.gz"
done

#Dejar todo limpio
rm -rf  $TMP_PRO $TMP_VAL $TMP_SCS

