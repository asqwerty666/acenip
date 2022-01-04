# Neurodegeneration Assessment from MRI

## Usage

N values are estimated with the script *nplus.r*. you must have installed the following libraries,

  - e1071
  - caret
  - caTools
  - ADNIMERGE

Basically, a bayes prior is built taking those baseline subjects from ADNIMERGE database diagnosed as *Dementia* and  *CN*. It is assumed that *Dementia* => N+ and  *CN* => N-. Then a CSV file, with Freesurfer segmentation data, is neededas input. This input CSV should also contain the variable *AGE*, with the age of subjects. 

---
**Note for ACE users:** In order to extract Freesurfer data right permission to the XNAT project are needed as well as the [xnatapic](https://github.com/asqwerty666/xnatapic) client properly installed and configured. Subject's age could found al project general database and inserted easily into de CSV file.

For instance, in the case of project *bioface19*, first we get the Freesurfer data,

```
xnat_pullfs.pl -s aseg -x bioface19 -o bf_base_aseg.csv
xnat_pullfs.pl -s aparc -x bioface19 -o bf_base_aparc.csv
join -t, bf_base_aseg.csv bf_base_aparc.csv > bf_base.csv
```

and with a previous file containing age of individuals,

```
$ head bf_age.csv 
Subject_ID,AGE
B001,64
B002,53
B003,60
B004,64
B005,62
B006,64
B007,62
B008,58
B009,51
```

we can built a single file with joined data,

```
join -t, bf_base.csv bf_age.csv > input_data.csv
```

---
The script is executed as simple as,

```
Rscript nplus.r
```

and we get the classifier results in the file *classifier_output.csv*,

```
$ head classifier_output.csv 
Subject_ID,ND
B001,0
B002,1
B003,0
B004,1
B005,1
B006,1
B007,0
B008,0
B009,1
```
Also, there are three other output files with plots for hippocampus, middle temporal cortex and entorhinal cortex vs subject's age. Those are images in postscript format and are named *classifier_output_hippocampus.ps*, *classifier_output_middletemporal.ps*, *classifier_output_entorhinal.png* respectively.

---
Note: Postscript images could be converted easily to wide variety of format with tools like *ImageMagick* doing somethign as simple as,
```
convert classifier_output_hippocampus.ps -rotate 90 classifier_output_hippocampus.png
```
---
![classifier HV vs AGE](classifier_output.png)

For a better understanding of results, the cortical and subcortical volumes plotted on these plots are corrected by intracranial volume using the residual correction method (for ICV adjusment methods, see https://pubmed.ncbi.nlm.nih.gov/25339897/).

## Cite it

The full metodology is poorly written in english and available in MS Office format at *nplus_method.docx* document.

## More info

All the info for building the method, alternatives, several test, possible extensions and so on, is available (in spanish) at,

https://detritus.fundacioace.com/wiki/doku.php?id=neuroimagen:bioface_atn

