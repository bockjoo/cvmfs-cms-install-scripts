#!/bin/sh
MINUTE=$(date +%M)
host=cms.rc.ufl.edu
port=8443
weborigin=http://${host}:${port}/cmssoft/cvmfs
workdir=$HOME/services/external/apache2/htdocs/cmssoft
workdir=$HOME
if [ $# -gt 0 ] ; then
   workdir=$1
fi
files="lhapdf_list.txt list_requested_arch_cmssws_cvmfs.txt cron_install_cmssw.config"
i=0
for f in $files ; do
   i=$(expr $i + 1)
   echo "[ $i ]" INFO dowloading $f to $workdir/$f
   wget -q -O $workdir/$f $weborigin/$f
   status=$?
   if [ $status -eq 0 ] ; then
      /bin/cp $workdir/$f.r $workdir/$f
   else
      echo ERROR wget -q -O $workdir/$f.r $weborigin/$f
      continue
   fi
   echo "[ $i ]" $f: Download Status: $status
   echo "[ $i ]" Date Now: $(date)
   ls -al $workdir/$f
done
exit 0
