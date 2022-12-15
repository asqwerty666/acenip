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

            %conn = xget_session();

- xget\_subjects

    Get the list of subjects of a project into a HASH. 
    El HASH de input, _%sbjs_, se construye como _{ XNAT\_ID => Label }_

    usage: 

            %sbjs = xget_subjects(host, jsession, project);

- xget\_sbj\_id

    Get the subject's ID if the subject label inside a project is known.
    Sometimes I need to do this and is not difficult to implement

    usage:

            $sbj_id = xget(host, jsession, project, subject_label);

- xget\_sbj\_data

    Get the subject's metadata. Not too much interesting but to extract
    the subject label.

    usage:

            $xdata = xget_sbj_data(host, jsession, subject, field);

- xput\_sbj\_data 

    Set a parameter for given subject

    usage:

            $xdata = xput_sbj_data(host, jsession, subject, field, value)

    This is the same as 

            curl -f -b "JSESSIONID=57B615F6F6AEDC93E604B252772F3043" -X PUT "http://detritus.fundacioace.com:8088/data/subjects/XNAT_S00823?gender=female,dob=1947-06-07"

    but is intended to offer a Perl interface to updating subject data. If everything is OK, it returns the subject ID or nothing if somethign  goes wrong. So you could check your own disaster.

    Notice that _field_ could be a comma separated list but you should fill _value_ with the correpondent list.

- xget\_sbj\_demog

    Get demographics variable from given subject, if available

    usage:

            $xdata = xget_sbj_demog(host, jsession, project, subject, field);

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

            $experiment_ID = xget_mri(host, jsession, project, subject)

- xget\_fs\_data

    Get the full Freesurfer directory in a tar.gz file.
    DEPRECATED

    usage: 

            $result = xget_fs_data(host, jsession, project, experiment, output_path);

    Return 1 if OK, 0 otherwise.

- xget\_fs\_stats

    Get a single stats file from Freesurfer segmentation

    This is deprecated by xget\_res\_file() and should disapear soon :-(

    usage:

            $result = xget_fs_stats(host, jsession, experiment, stats_file, output_file) 

    Returns 1 if OK, 0 otherwise.

- xget\_fs\_allstats

    Get all stats files from Freesurfer segmentation and write it down at selected directory.
    DEPRECATED, should be removed

    usage:

            xget_fs_allstats(host, jsession, experiment, output_dir)

- xget\_fs\_qc

    Get Freeesurfer QC info.

    I'm sure this could be deprecated by xget\_res\_data(), so better do not use it.

    usage:

            %fsqc = xget_fs_qc(host, jsession, experiment);

    Output is a hash with _rating_ and _notes_

- xget\_pet

    Get the XNAT PET experiment ID

    usage: 

            $experiment_id = xget_pet(host, jsession, project, subject)

    Returns experiment ID.

- xget\_pet\_reg

    Download de pet registered into native space in nifti format

    usage: 

            $result = xget_pet_reg(host, jsession, experiment, nifti_output);

    Returns 1 if OK, 0 otherwise.

- xget\_pet\_data

    Get the PET FBB analysis results into a HASH

    usage:

            %xresult = xget_pet_data(host, jsession, experiment);

    Returns a hash with the results of the PET analysis

- xput\_report

    Upload a pdf report to XNAT.

    Deprecated. Use a call to xcreate\_res() and xput\_res\_file() instead.

    usage: 

            xput_report(host, jsession, subject, experiment, pdf_file);

- xput\_rvr

    Upload a JSON file with VR data.

    This is deprecated by xput\_res\_file()

    usage: 

            xput_rvr(host, jsession, experiment, json_file);

- xcreate\_res 

    Create an empty experiment resource

    usage:

            xcreate_res(host, jsession, experiment, res_name)

- xput\_res\_file

    Upload file as experiment resource

    usage:

            xput_res(host, jsession, experiment, type, file, filename)

- xput\_res\_data 

    Upload hash to an experiment resource as a json file

    usage:

            xput_res_data(host, jsession, experiment, type, file, hash_ref)

- xget\_res\_data

    Download data from experiment resource given type and json name

    usage:

            %xdata = xget_res_data(host, jsession, experiment, type, filename)

    Returns a hash with the JSON elements

- xget\_res\_file

    Download file from experiment resource

    usage:

            $result = xget_res_file(host, jsession, experiment, type, filename, output)

- xlist\_res

    Put the resources files into a HASH. 
    Output is a hash with filenames and URI of each element stored at the resource.

    usage:

            %xdata = xlist_res(host, jsession, project, experiment, resource); 

- xget\_rvr\_data

    Get RVR JSON data into a hash

    Give me a break. Deprecated by xget\_res\_data()

    usage: 

            %xdata = xget_rvr_data(host, jsession, URI);

- xget\_dicom

    Download the full DICOM for a given experiment into the desired output directory.

    usage:

            xget_dicom(host, jsession, experiment, output_dir)
