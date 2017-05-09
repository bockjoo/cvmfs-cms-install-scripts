#!/bin/bash
if [ ! -d /etc/grid-security ] ; then
   echo ERROR nothing to do
   exit 1
fi
which cvmfs_server 2>/dev/null 1>/dev/null
if [ $? -ne 0 ] ; then
   echo ERROR not a cvmfs management node
   exit 1
fi
input_dir=/etc/grid-security
rsync_dir=/cvmfs/cms.cern.ch/grid/etc
cvmfs_server transaction
if [ $? -ne 0 ]  ; then
   echo ERROR cvmfs_server transaction failed
   exit 1
fi
if [ ! -d $rsync_dir ] ; then
   mkdir -p $rsync_dir
fi

rsync -arupq --delete $input_dir $rsync_dir
if [ $? -eq 0 ] ; then
   cvmfs_server publish
else
   cvmfs_server abort -f
fi
exit 0
