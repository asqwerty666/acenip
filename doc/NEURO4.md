# NEURO4 

This is a set of functions for helping in the pipeline

- print\_help

    just print the help

    this funtions reads the path of a TXT file and print it at STDOUT

    usage: 

            print_help(help_file);

- escape\_name

    This function takes a string and remove some especial characters
    in order to escape directory names with a lot of strange symbols.

    It returns the escaped string

    usage: 

            escape_name(string);

- trim

    This function takes a string and remove any trailing spaces after and before the text

    usage: 

            trim(string);

- check\_or\_make

    This is mostly helpless, just takes a path,
    checks if exists and create it otherwise

    usage: 

            check_or_make(path);

- inplace

    This function takes a path and a file name or two paths
    and returns a string with a single path as result of
    the concatenation of the first one plus the second one

    usage: 

            inplace(path, filename);

- load\_project

    This function take the name of a project, reads the configuration file
    that is located at ~/.config/neuro/ and return every project configuration
    stored as a hash that can be used at the scripts

    usage: 

            load_project(project_name);

- check\_subj

    Here the fun begins

    This function takes as input the name of the project and the subject ID
    Then it seeks along the BIDS structure for this subject and returns a hash,
    containing the MRI proper images. 

    It should return a single value, except for the T1w images, where an array 
    is returned. This was though this way because mostly a single session is done.
    However, the skill to detect more than one MRI was introduced to allow the 
    movement correction when ADNI images are analyzed

    So, for T1w images the returned hash should be asked as

            @{$nifti{'T1w'}}

    but for other kind of image it should asked as

            $nifti{'T2w'}

    usage: 

            check_subj(project_path, bids_id);  

- check\_pet

    This function takes as input the name of the project and the subject ID
    Then it seeks along the BIDS structure for this subject and returns a hash,
    containing the PET proper images.

    If also a tracer is given as input, then the returned hash contains the PET-tau
    associated to this tracer. This was introduced as part of a project were the subjects 
    were analyzed with different radiotracers.

    If no tracer is given, it will seek for the FBB PETs. Those PETs are stored as 

            - single: 4x5min
            - combined: 20min

    usage: 

            check_pet(project_path, bids_id, $optional_radiotracer);

- check\_fs\_subj

    This function checks if the Freesurfer directory of a given subjects exists

    usage: 

            check_fs_subj(freesurfer_id) 

- get\_lut

    I really don't even remenber what this shit does

- run\_dckey

    Get the content of a public tag from a DICOM file.

    usage: 

            run_dckey(key, dicom)

- dclokey

    Get the content of a private tag from a DICOM file.

    usage: 

            dclokey(key, dicom)

- centiloid\_fbb

    Returns the proper centiloid value for a given SUVR.
    Only valid for FBB.

    usage: 

            centiloid_fbb(suvr);

- populate

    Takes a pattern and a filename and stores the content of the file
    into a HASH according to the given pattern

    usage: 

            populate(pattern, filename); 

- get\_subjects

    Parse a project database taking only the subjects and storing them into an array.
    The databse is expected to be build as,

            0000;name 

    usage: 

            get_subjects(filename);

- get\_list

    Parse a project database taking only the subjects and storing them into an array.
    The databse is expected to be build with a four digits number at the beginning of 
    line. Is similar to get\_subjects() function but less restrictive

    usage: 

            get_list(filename);

- get\_pair

    A single file is loaded as input and parse into a HASH. 
    The file should be written in the format:

            key;value

    usage: 

            get_pair(filename);

- shit\_done

    this function is intended to be used  after a script ends 
    and then an email is send to the user 
    with the name of the script, the name of the project and th results attached

    usage: 

            shit_done(script_name, project_name, attached_file)

- cut\_shit

    This function takes a project database and a file with a list, then
    returns the elements that are common to both.
    It is intended to be used to restrict the scripts action 
    over a few elements. It returns a single array. 

    If it is correctly used, first the db is identified with 
    _load\_project()_ function and then passed through this function
    to get the array of subjects to be analyzed. If the file with 
    the cutting list do not exist, an array with all the subjects 
    is returned.

    usage: 

            cut_shit(db, list);

- getLoggingTime

    This function returns a timestamp based string intended to be used 
    to make unique filenames 

    Stolen from Stackoverflow

    usage: 

            getLoggingTime(); 
