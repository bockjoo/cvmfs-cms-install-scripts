#!/bin/bash
# versiono 0.0.3
version=0.0.3
# initial values:
Username=$(/usr/bin/whoami) # "shared"
export RSYNC_PASSWORD=$(cat $HOME/.rsync_pass.1234567890)
name="/cvmfs/cms.cern.ch"
host="vocms10"
if [ $# -lt 2 ] ; then
   echo ERROR $(basename $0) "SCRAM_ARCH" "HOST" "[cms_common_rsync]"
   exit 1
fi
arg=$1
host=$2
if [ "x$3" == "xcrab3" ] ; then
   rsync_name="/cvmfs/cms.cern.ch/crab3/${arg}"
   echo INFO rsync ing : rsync -arzuvp $Username@$host:$rsync_name $(dirname $rsync_name)
   rsync -arzuvp $Username@$host:$rsync_name $(dirname $rsync_name)
   rsync_status=$?
   for f in crab_slc6.sh crab_slc6.csh crab_pre_slc6.sh crab_pre_slc6.csh; do
       [ -f $(dirname $rsync_name)/$f ] && rm -f $(dirname $rsync_name)/$f
       echo INFO rsync -arzuvp $Username@$host:$(dirname $rsync_name)/$f $(dirname $rsync_name)
       rsync -arzuvp $Username@$host:$(dirname $rsync_name)/$f $(dirname $rsync_name)
       rsync_status=$(expr $rsync_status + $?)
   done
   exit $rsync_status
fi

rsync_name="/cvmfs/cms.cern.ch/${arg}"
echo INFO rsync ing
rsync -arzuvp $Username@$host:$rsync_name $name
rsync_status=$?
echo INFO rsync status = $rsync_status
if [ $# -gt 2 ] ; then
   if [ $3 -eq 1 ] ; then
      echo INFO rsync ing rsync -arzuvp $Username@$host:/cvmfs/cms.cern.ch/common $name
      rsync -arzuvp $Username@$host:/cvmfs/cms.cern.ch/common $name
      rsync_status=$(expr $rsync_status + $?)
      echo INFO rsync ing rsync -arzuvp $Username@$host:/cvmfs/cms.cern.ch/etc $name
      rsync -arzuvp $Username@$host:/cvmfs/cms.cern.ch/etc $name
      rsync_status=$(expr $rsync_status + $?)
      echo INFO rsync ing rsync -arzuvp $Username@$host:/cvmfs/cms.cern.ch/share $name
      rsync -arzuvp $Username@$host:/cvmfs/cms.cern.ch/share $name
      rsync_status=$(expr $rsync_status + $?)
   fi
fi
exit $rsync_status
