#!/bin/bash

PROY=$1
shift
SUBJECT=$1
shift
DIR=$1
shift

#Todos los archivos en el directorio son de la misma fecha y paciente
#DATE=$(dckey -k "AcquisitionDate" ${DIR}/$(ls ${DIR}/ | head -n 1) 2>&1)
PTID=$(dckey -k "PatientID" ${DIR}/$(ls ${DIR}/ | head -n 1) 2>&1 | sed 's/[ \t]$//g')

#Crear el proyecto y el sujecto
if [[ -z $(xnatapic list_projects --project_id ${PROY}) ]]; then
	xnatapic create_project --project_id ${PROY};
fi
if [[ -z $(xnatapic list_subjects --project_id ${PROY} --subject_id ${SUBJECT}) ]]; then
        xnatapic create_subject --project_id ${PROY} --subject_id ${SUBJECT};
fi

#Subir los archivos
xnatapic upload_dicom --project_id ${PROY} --subject_id ${SUBJECT} --mixed-series --experiment_id ${PTID} ${DIR}
#xnatapic upload_dicom --project_id ${PROY} --subject_id ${SUBJECT} --experiment_id ${PTID} ${DIR}

#Ejecutar pipeline de conversion
DCMC=$(xnatapic list_pipelines --project_id ${PROY} | grep DicomToNifti_X)
if [[ $DCMC == DicomToNifti_X ]]; then 
	xnatapic run_pipeline --project_id ${PROY} --pipeline DicomToNifti_X --experiment_id ${PTID}; 
fi
