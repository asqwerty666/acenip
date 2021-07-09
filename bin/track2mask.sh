#!/bin/sh
 
Usage() {                      
    echo ""                                                                                                                                                              
    echo "Usage: track2mask.sh  <file> <thr>"                                                                                                          
    echo ""                                                                                                                                                              
    echo "You must have FSL installed in order to run this script"                                                                                                       
    echo ""                                                                                                                                                              
    exit 1                                                                                                                                                               
}                                                                                                                                                                        
 
[ "$1" = "" ] && Usage

pollo=`${FSLDIR}/bin/remove_ext $1`
shift
thr=$1
shift
max=($(${FSLDIR}/bin/fslstats ${pollo} -r | awk '{print $2}'))
cut=$(echo $max*$thr | bc)
#cut=$(echo 100*$thr | bc)
${FSLDIR}/bin/fslmaths ${pollo} -thr ${cut} -bin ${pollo}_mask
#${FSLDIR}/bin/fslmaths ${pollo} -thrp ${cut} ${pollo}_mask
exit 0
