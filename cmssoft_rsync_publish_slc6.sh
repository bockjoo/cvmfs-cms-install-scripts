#!/bin/sh
export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
export LANG="C"
vm_host=vocms10
a=slc6_amd64_gcc481
if [ $# -lt 1 ] ; then
   echo ERROR $(basename $0) slc6_XX_YYY
   exit 1
fi
a=$1

echo "$a" | grep slc6_
if [ $? -ne 0 ] ; then
   echo ERROR $(basename $0) it must start with slc6_ while it is $a
   exit 1
fi

function add_nested_entry_to_cvmfsdirtab () {
   if [ $# -lt 1 ] ; then
      echo ERROR add_nested_entry_to_cvmfsdirtab arch
      return 1
   fi
   thearch=$1
   for thecmssw in cmssw cmssw-patch ; do
      n_a_cmssw=$(ls  $VO_CMS_SW_DIR/${thearch}/cms/$thecmssw | wc -l)
      if [ $n_a_cmssw -gt 0 ] ; then
         grep -q /${thearch}/cms/$thecmssw $VO_CMS_SW_DIR/.cvmfsdirtab
         if [ $? -eq 0 ] ; then
            echo INFO the entry /${thearch}/cms/$thecmssw is already in $VO_CMS_SW_DIR/.cvmfsdirtab
         else
            echo INFO adding the entry /${thearch}/cms/$thecmssw to $VO_CMS_SW_DIR/.cvmfsdirtab
            echo /${thearch}/cms/$thecmssw >> $VO_CMS_SW_DIR/.cvmfsdirtab
            printf "add_nested_entry_to_cvmfsdirtab INFO: added the entry /${thearch}/cms/$thecmssw to $VO_CMS_SW_DIR/.cvmfsdirtab\n" | mail -s "add_nested_entry_to_cvmfsdirtab INFO: Nested CVMFS dir entry added for $thearch" $notifytowhom
         fi
      fi
   done
   
   return 0
}

echo INFO rsyncing slc6
$HOME/cmssoft_rsync_slc6.sh $a $vm_host
if [ $? -ne 0 ] ; then
   echo ERROR rsync failed
   exit 1
fi

echo INFO nested entry
add_nested_entry_to_cvmfsdirtab ${a}
if [ $? -ne 0 ] ; then
   echo ERROR nested entry failed
   exit 1
fi

echo INFO publishing cvmfs
time cvmfs_server publish

exit 0
