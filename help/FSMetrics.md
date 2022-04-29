# FSMetrics

Bunch of helpers for storing ROI structure and relative data

- fs\_file\_metrics

    This function does not read any input. It sole purpose is to
    returns a HASH containing the templates of order for converting Freesurfer (FS)
    results into tables.

    Any hash element is composed by the template ('order'), a boolean ('active') to decide 
    if the FS stats will be processed and the name of the FS stat file ('file'). 
    The order template has two wildcards (<list> and <fs\_output>) that should be 
    parsed and changed by the FS subject id and the output directory where the
    data tables will be stored for each subject

    The function could be invoked as,

            my %stats = fs_file_metrics();

    in any script where this information would be needed. 

    The boolean element could be used to choose the stats that should 
    be processed and can be added or modified even at run time if needed. The 
    stored booleans only provided a decent default

- fs\_fbb\_rois

    _deprecated_

    This function exports a HASH that contains the Freesurfer composition of the 
    usual segmentations used for building the SUVR ROI

- tau\_rois

    This function takes a string as input and returns an ARRAY containing
    the list of ROIs that should be build and where the SUVR should be calculated 

    It is intended to be used for PET-Tau but could be used anywhere

    By default a list of Braak areas are returned. If the input string is **alt**
    a grouping of those Braak areas is returned. If the purpose is to build 
    a meta\_temporal ROI the string **meta** should be passed as input

    The main idea here is read the corresponding file for each ROI, stored at
    `PIPEDIR/lib/tau/` and build each ROI with the FS LUTs store there

- pet\_rois

    This function takes a string as input and returns an ARRAY containing
    the list of ROIs that should be build and where the SUVR should be calculated

    Input values are **parietal**, **frontal**, **pieces** or **global** (default)

    The main idea here is read the corresponding file for each ROI, stored at
    `PIPEDIR/lib/pet/` and build each ROI with the FS LUTs stored there
