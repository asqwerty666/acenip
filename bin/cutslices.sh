#!/bin/sh

Usage() {
    echo ""
    echo "Usage: cutslices.sh  <input> <output> <n>"
    echo ""
    echo "Cut <n> slices from <input> and save result as <output>"
    echo ""
    echo "You must have FSL installed in order to run this script"
    echo ""
    echo ""
    exit 1
}

[ "$3" = "" ] && Usage

debug=0

# }}}
# {{{ parse main arguments

in=`${FSLDIR}/bin/remove_ext $1`
shift

out=`${FSLDIR}/bin/remove_ext $1`
shift

n=$1
shift

${FSLDIR}/bin/fslreorient2std ${in} ${in}_tmp
${FSLDIR}/bin/fslsplit ${in}_tmp ${in}_2crop -z
for ((x=0;x<=$n;x+=1)); do a=`printf "%04d" $x`; ${FSLDIR}/bin/imrm ${in}_2crop$a; done
${FSLDIR}/bin/fslmerge -z $out ${in}_2crop* 

if [ $debug = 0 ] ; then
	rm ${in}_tmp*
    rm ${in}_2crop* 
fi
