# XNATACE

- xconf

    Publish path of xnatapic configuration file

    usage: 

            $path = xconf();

- xget\_conf

    Get the XNAT connection data into a HASH

    usage: 

            %xnat_data = xget_conf()

- xget\_session 

    Create a new JSESSIONID on XNAT. Return the connection data
    for the server AND the ID of the created session

    usage: 

            xget_session();

- xget\_subjects

    Get the list of subjects of a project into a HASH. 
    El HASH de input, _%sbjs_, se construye como _{ XNAT\_ID => Label }_

    usage: 

            %sbjs = xget_subjects(host, jsession, project);

- xget\_sbj\_data

    Get the subjects metadata. Not too
    much interesting but to extract
    the subject label.

    usage:

            $xdata = xget_sbj_data(host, jsession, subject, field);

- xget\_sbj\_demog

    Get demographics variable from given subject, if available

    usage:

            $xdata = xget_sbj_demog(host, jsession, subject, field);

- xget\_exp\_data

    Get a data field of an experiment.
    The desired field shoud be indicated as input.
    By example, if you want the date of the experiment this is 
    seeked as 

            my $xdate = xget_exp_data($host, $session_id, $experiment, 'date')

    There are some common fields as _date_, _label_ or _dcmPatientId_ 
    but in general  you should look at,

            curl -X GET -b JSESSIONID=00000blahblah "http://myhost/data/experiments/myexperiment?format=json" 2>/dev/null | jq '.items[0].data_fields'

    in order to know the available fields

    usage:

            $xdata = xget_exp_data(host, jsession, experiment, field);

- xget\_mri

    Get the XNAT MRI experiment ID

    usage: 

            xget_mri(host, jsession, project, subject)

- xget\_fs\_data

    Get the full Freesurfer directory in a tar.gz file

    usage: 

            xget_fs_data(host, jsession, project, experiment, output_path)
            

- xget\_fs\_stats

    Get a single stats file from Freesurfer segmentation

    usage:

            xget_fs_stats(host, jsession, experiment, stats_file, output_file) 

- xget\_fs\_allstats

    Get all stats files from Freesurfer segmentation and write it down at selected directory

    usage:

            xget_fs_allstats(host, jsession, experiment, output_dir)

- xget\_fs\_qc

    Get Freeesurfer QC info

    usage:

            xget_fs_qc(host, jsession, experiment);

    Output is a hash with _rating_ and _notes_

- xget\_pet

    Get the XNAT PET experiment ID

    usage: 

            xget_pet(host, jsession, project, subject)

- xget\_pet\_reg

    Download de pet registered into native space in nifti format

    usage: 

            xget_pet_reg(host, jsession, experiment, nifti_output);

- xget\_pet\_data

    Get the PET FBB analysis results into a HASH

    usage:

            %xresult = xget_pet_data(host, jsession, experiment);

- xput\_report

    Upload a pdf report to XNAT

    usage: 

            xput_report(host, jsession, subject, experiment, pdf_file);

- xput\_rvr

    Upload a JSON file with VR data

    usage: 

            xput_rvr(host, jsession, experiment, json_file);

- xcreate\_res 

    Create an empty experiment resource

    usage:

            xcreate_res(host, jsession, experiment, res_name)

- xput\_res 

    Upload data to an experiment resource

    usage:

            xput_res(host, jsession, experiment, type, file, filename)

- xget\_res

    Dowload data from experiment resource given type and json name

    usage:

            xget_res(host, jsession, experiment, type, filename)

- xget\_rvr

    Get VR results into a HASH. Output is a hash with filenames and URI of each element stored at RVR

    usage: 

            xget_rvr(host, jsession, project, experiment);

- xget\_rvr\_data

    Get RVR JSON data into a hash

    usage: 

            xget_rvr_data(host, jsession, URI);

- xget\_dicom

    Get the full DICOM for a given experiment

    usage:

            xget_dicom(host, jsession, experiment, output_dir)
