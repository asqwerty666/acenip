#!/bin/sh

Usage() {
    echo ""
    echo "Usage: dti_proc_deprecated.sh  <subject> <dwi> <output_dir>"
    echo ""
    echo "run dti preprocessing (dtifit) over <dwi> image"
    echo "and place it as <subject> and its results into <output_dir>"
    echo ""
    echo "You must have FSL installed in order to run this script"
    echo ""
    echo ""
    exit 1
}


[ "$3" = "" ] && Usage

debug=0
b_in=$1
shift
in=`${FSLDIR}/bin/remove_ext $1`
shift

out=`${FSLDIR}/bin/remove_ext $1`
shift

td=${out}'/.tmp_'${b_in}
if [ ! -d "$out" ]; then
        mkdir $out
fi
if [ ! -d "$td" ]; then
	mkdir $td
fi

echo "DTI preproccessing begins ..."
echo [`date`]
echo
echo "Copying files for ${b_in} to ${td}/"
echo
${FSLDIR}/bin/imcp ${in} ${td}/${b_in}
cp ${in}.bval ${td}/bvals
cp ${in}.bvec ${td}/bvecs
echo "Doing correction on ${td}/${b_in}"
echo
${FSLDIR}/bin/eddy_correct ${td}/${b_in} ${td}/data 0
echo "Doing BET on ${td}/data now"
echo
${FSLDIR}/bin/bet ${td}/data ${td}/nodif_brain -f 0.3 -g 0 -n -m 
echo "Running dtifit on ${td}/data"
echo
${FSLDIR}/bin/dtifit --data=${td}/data --out=${td}/dti --mask=${td}/nodif_brain_mask --bvecs=${td}/bvecs --bvals=${td}/bvals
echo "I will copy all output files to ${out}/${b_in}_XXXXX"
echo
for x in ${td}/dti*; do ${FSLDIR}/bin/imcp ${x} ${out}/${b_in}_$(basename $x); done;
${FSLDIR}/bin/imcp ${td}/nodif_brain_mask ${out}/${b_in}_nodif_brain_mask
${FSLDIR}/bin/imcp ${td}/data ${out}/${b_in}_data
echo "Registering FA to MNI Functional Space now ...."
${FSLDIR}/bin/flirt -ref ${FSLDIR}/data/standard/FMRIB58_FA_1mm -in ${out}/${b_in}_dti_FA -omat ${out}/${b_in}_tmp_diff2standard.mat
${FSLDIR}/bin/fnirt --in=${out}/${b_in}_dti_FA --aff=${out}/${b_in}_tmp_diff2standard.mat --cout=${out}/${b_in}_tmp_diff2standard_warp --config=FA_2_FMRIB58_1mm
${FSLDIR}/bin/applywarp --ref=${FSLDIR}/data/standard/FMRIB58_FA_1mm --in=${out}/${b_in}_dti_FA --warp=${out}/${b_in}_tmp_diff2standard_warp --out=${out}/${b_in}_tmp_dti_std_FA
${FSLDIR}/bin/fslmaths ${out}/${b_in}_tmp_dti_std_FA -mas ${FSLDIR}/data/standard/FMRIB58_FA_1mm ${out}/${b_in}_dti_std_FA
echo "Registering MD to MNI Functional Space now ...."
${FSLDIR}/bin/applywarp --ref=${FSLDIR}/data/standard/FMRIB58_FA_1mm --in=${out}/${b_in}_dti_MD --warp=${out}/${b_in}_tmp_diff2standard_warp --out=${out}/${b_in}_tmp_dti_std_MD
${FSLDIR}/bin/fslmaths ${out}/${b_in}_tmp_dti_std_MD -mas ${FSLDIR}/data/standard/FMRIB58_FA_1mm ${out}/${b_in}_dti_std_MD

if [ $debug = 0 ] ; then
	echo "Removing temporary files"
	echo
    rm -rf ${td}
    rm -rf ${out}/${b_in}_tmp_*
fi

exit 0
