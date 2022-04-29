# XNATACE

- xconf

    Get the XNAT connection data into a HASH

    usage: 
    	%xnat\_data = xconf(configuration\_file)

- xget\_pet

    Get the XNAT PET experiment ID

    usage: 
    	xget\_pet(host, jsession, project, subject)

- xget\_mri

    Get the XNAT MRI experiment ID

    usage: 
    	xget\_mri(host, jsession, project, subject)

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
    El HASH de input, _%sbjs_, se construye como _{ XNAT\_ID =_ Label }>

    usage: 
    	%sbjs = xget\_subjects(host, jsession, project);

- xget\_pet\_reg

    Download de pet registered into native space in nifti format

    usage: 
    	xget\_pet\_reg(host, jsession, experiment, nifti\_output);
