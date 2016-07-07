#!/bin/sh
# versiono 0.0.1
version=0.0.1
notifytowhom=bockjoo@phys.ufl.edu
export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
lhapdf_top=$VO_CMS_SW_DIR/lhapdf

function cvmfs_server_transaction_check () {
   status=$1
   what="$2"
   itry=0
   while [ $itry -lt 10 ] ; do
     if [ $status -eq 0 ] ; then
      return 0
     else
      printf "$what cvmfs_server transaction Failing\n" | mail -s "ERROR cvmfs_server transaction Failed" $notifytowhom
      echo INFO retrying $itry
      cvmfs_server abort -f
      cvmfs_server transaction
      status=$?
      [ $status -eq 0 ] && return 0
     fi
     itry=$(expr $itry + 1)
   done
   return 1
}

if [ $# -lt 1 ] ; then
   echo ERROR $(basename $0) release
   echo Usage: $(basename $0) 6.1.4a
   exit 1
fi

release=$1
dest_nested_catalog=pdfsets/$release
if [ ! -d ${lhapdf_top}/$dest_nested_catalog ] ; then
   echo ERROR ${lhapdf_top}/$dest_nested_catalog does not exist
   exit 1
fi

cvmfs_server transaction
status=$?
what="$(basename $0)"
cvmfs_server_transaction_check $status $what
if [ $? -eq 0 ] ; then
   echo INFO transaction OK for $what
else
   printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
   exit 1
fi

#cd ${lhapdf_top}/$dest_nested_catalog
realv=$(echo $dest_nested_catalog | cut -d/ -f2)
if [ -f ${lhapdf_top}/checksum_pdfsets_${realv}.txt ] ; then
   cp ${lhapdf_top}/checksum_pdfsets_${realv}.txt ${lhapdf_top}/checksum_pdfsets_${realv}.txt.$(date +%s)
fi
rm -f ${lhapdf_top}/checksum_pdfsets_${realv}.txt
touch ${lhapdf_top}/checksum_pdfsets_${realv}.txt
for f in $(find ${lhapdf_top}/$dest_nested_catalog -type f -name "*" -print) ; do
    echo DEBUG $f
    grep -q $f ${lhapdf_top}/checksum_pdfsets_${realv}.txt
    if [ $? -ne 0 ] ; then
       echo DEBUG calculating checksum for $f
       /usr/bin/cksum $f >> ${lhapdf_top}/checksum_pdfsets_${realv}.txt
    fi
done
cd
time cvmfs_server publish 2>&1 |  tee $HOME/cvmfs_server+publish+create+lhapdf+checksum+${release}.log

status=$?
if [ $status -eq 0 ] ; then
   printf "$(basename $0) cvmfs_server_publish OK \n$(cat $HOME/cvmfs_server+publish+create+lhapdf+checksum+${release}.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish for lhapdf checksum $release OK" $notifytowhom
else
   echo ERROR failed cvmfs_server publish
   rm -f ${lhapdf_top}/checksum_pdfsets_${realv}.txt
   printf "$(basename $0) cvmfs_server publish failed\n$(cat $HOME/cvmfs_server+publish+create+lhapdf+checksum+${release}.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish failed" $notifytowhom
   ( cd ; cvmfs_server abort -f ; ) ;
   exit 1
fi
exit 0