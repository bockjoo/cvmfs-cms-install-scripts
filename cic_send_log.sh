#!/bin/sh
workdir=$HOME # /home/shared
export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
export LANG="C"
notifytowhom=bockjoo@phys.ufl.edu
cvmfs_installations=/cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates
gatekeeper_hostname=$(/bin/hostname -f)

if [ -f $VO_CMS_SW_DIR/COMP/slc5_amd64_gcc434/external/python/2.6.4/etc/profile.d/init.sh ] ; then
   source $VO_CMS_SW_DIR/COMP/slc5_amd64_gcc434/external/python/2.6.4/etc/profile.d/init.sh 2>&1
else
   echo $(basename $0) ERROR $VO_CMS_SW_DIR/COMP/slc5_amd64_gcc434/external/python/2.6.4/etc/profile.d/init.sh does not exist
   printf "$(basename $0) ERROR $VO_CMS_SW_DIR/COMP/slc5_amd64_gcc434/external/python/2.6.4/etc/profile.d/init.sh does not exist\n" | mail -s "ERROR missing python" $notifytowhom
   exit 1
fi

echo INFO executing python $workdir/cic_send_log.py --sendciclog $cvmfs_installations $gatekeeper_hostname
python $workdir/cic_send_log.py --sendciclog $cvmfs_installations $gatekeeper_hostname 2>&1 | tee $workdir/cic_log_sent.log
thestatus=$?

echo INFO status=$thestatus

exit $thestatus

