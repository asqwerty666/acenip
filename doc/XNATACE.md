# XNATACE

- xconf

    Publish path of xnatapic configuration file

    usage $path = xconf();

- xget\_conf

    Get the XNAT connection data into a HASH

    usage: 
    	%xnat\_data = xget\_conf()

- xget\_pet

    Get the XNAT PET experiment ID

    usage: 
    	xget\_pet(host, jsession, project, subject)

- xget\_mri

    Get the XNAT MRI experiment ID

    usage: 
    	xget\_mri(host, jsession, project, subject)

- xget\_fs\_data
Get the full Freesurfer directory in a tar.gz file

    usage: 
    	xget\_fs\_data(host, jsession, project, experiment, output\_path)

- xget\_fs\_stats

    Get a single stats file from Freesurfer segmentation

    usage:

            xget_fs_stats(host, jsession, project, experiment, stats_file, output_file) 

- xget\_session 

    Create a new JSESSIONID on XNAT

    usage: 
    	xget\_session(\\%xconf);

- xput\_report

    Upload a pdf report to XNAT

    usage: 
    	xput\_report(host, jsession, subject, experiment, pdf\_file);

- xput\_rvr

    Upload a JSON file with VR data

    usage: 
    	xput\_rvr(host, jsession, experiment, json\_file);

- xget\_rvr

    Get VR results into a HASH. Output is a hash with filenames and URI of each element stored at RVR

    usage: 
    	xget\_rvr(host, jsession, project, experiment);

- xget\_rvr\_data

    Get RVR JSON data into a hash

    usage: 
    	xget\_rvr\_data(host, jsession, URI);

- xget\_subjects

    Get the list of subjects of a project into a HASH. 
    El HASH de input, _%sbjs_, se construye como _{ XNAT\_ID => Label }_

    usage: 
    	%sbjs = xget\_subjects(host, jsession, project);

- xget\_pet\_reg

    Download de pet registered into native space in nifti format

    usage: 
    	xget\_pet\_reg(host, jsession, experiment, nifti\_output);

- xget\_pet\_data

    Get the PET FBB analysis results into a HASH

    usage:
    	%xresult = xget\_pet\_data(host, jsession, experiment);

- xget\_exp\_data

    Get a data field of an experiment.
    The desired field shoud be indicated as input.
    By example, if you want the date of the experiment this is 
    seeked as 
    	my $xdate = xget\_exp\_data($host, $session\_id, $experiment, 'date')

    There are some common fields as _date_, _label_ or _dcmPatientId_ 
    but in general  you should look at,

            curl -X GET -b JSESSIONID=00000blahblah "http://myhost/data/experiments/myexperiment?format=json" 2>/dev/null | jq '.items[0].data_fields'

    in order to know the available fields

    usage:
    	$xdata = xget\_exp\_data(host, jsession, experiment, field);

- xget\_sbj\_data

    Get the subjects metadata. Not too
    much interesting but to extract
    the subject label.

    usage:
    	$xdata = xget\_sbj\_data(host, jsession, subject, field);
