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
echo INFO cvmfs_server transaction
cvmfs_server transaction
if [ $? -ne 0 ]  ; then
   echo ERROR cvmfs_server transaction failed
   exit 1
fi
if [ ! -d $rsync_dir ] ; then
   echo mkdir -p $rsync_dir
   mkdir -p $rsync_dir
fi
echo INFO do vomses
cat /etc/vomses/* > $rsync_dir/vomses
echo INFO rsync -arupq --delete $input_dir $rsync_dir

rsync -arupq --delete $input_dir $rsync_dir
if [ $? -eq 0 ] ; then
   echo INFO cvmfs_server publish
   cvmfs_server publish
else
   echo INFO cvmfs_server abort -f
   cvmfs_server abort -f
   exit 1
fi
exit 0
