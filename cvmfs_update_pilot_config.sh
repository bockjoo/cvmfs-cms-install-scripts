#!/bin/sh
#
# Created by Bockjoo Kim, U of Florida
# Depends on $HOME/condor for the PYTHONPATH
# CVMFS 2.1/SLC6
# version=0.0.3
cvmfs_update_pilot_config=0.0.3
notifytowhom=bockjoo@phys.ufl.edu
pilot_config_git=https://github.com/bbockelm/kestrel.git
pilot_config_files="config_generated.ini kestrel/src/glidein_startup.sh"
#pilot_config_files="kestrel/src/glidein_startup.sh"

cd $HOME
[ -d tmp ] || mkdir -p tmp
cd tmp
if [ -d kestrel ] ; then
  cd kestrel
  git pull
  if [ $? -ne 0 ] ; then
     printf "$(basename $0) ERROR at $(pwd) git pull failed\n$(git pull 2>&1)\n" | mail -s "$(basename $0) git pull failed" $notifytowhom
     cvmfs_server abort -f
     exit 1
  fi
  cd ..
else
  #rm -rf kestrel
  git clone $pilot_config_git
fi
[ $? -eq 0 ] || { printf "$(basename $0) ERROR git clone $pilot_config_git failed\n" | mail -s "$(basename $0) git clone failed" $notifytowhom ; exit 1 ; } ;
echo DEBUG trying to write it to an output non-cvmfs
cd kestrel/src/

source $HOME/condor/condor.sh
export PYTHONPATH=$PYTHONPATH:$HOME/condor/lib/python

./kestrel_pilot_config --write -o $HOME/tmp/config_generated.ini
if [ $? -ne 0 ] ; then
     printf "$(basename $0) ERROR at $(pwd) kestrel_pilot_config --write -o $HOME/tmp/config_generated.ini failed\n$(./kestrel_pilot_config --write -o $HOME/tmp/config_generated.ini 2>&1)\n" | mail -s "$(basename $0) git pull failed" $notifytowhom
     cvmfs_server abort -f
     exit 1
fi
if [ $(date +%Y%m%d%H) == "2015042804" ] ; then
  echo \# >> $HOME/tmp/config_generated.ini
fi
status=0
files_to_be_updated=
for f in $pilot_config_files ; do
  ls -al $HOME/tmp/$f /cvmfs/cms.cern.ch/glidein/$(basename $f)
  diff $HOME/tmp/$f /cvmfs/cms.cern.ch/glidein/$(basename $f)
  s=$?
  #if [ $s -ne 0 ] ; then
  #   echo DEBUG copying $HOME/tmp/$f /cvmfs/cms.cern.ch/glidein/$(basename $f)
  #   cp -pR $HOME/tmp/$f /cvmfs/cms.cern.ch/glidein/$(basename $f)
  #fi
  status=$(expr $status + $s)
  echo DEBUG diff status for $f status=$status
  [ $s -eq 0 ] || files_to_be_updated="$files_to_be_updated $(basename $f)"
done

if [ $status -eq 0 ] ; then
   echo INFO Pilot config needs not to be regenerated
   #printf "$(basename $0) INFO: Pilot config needs not to be regenerated\n" | mail -s "$(basename $0) Pilot config needs not to be regenerated" $notifytowhom 
   exit 0
else
   #printf "$(basename $0) Warning: Pilot config needs to be regenerated\n$files_to_be_updated\n" | mail -s "$(basename $0) Pilot config needs to be regenerated" $notifytowhom
   printf "$(basename $0) Warning: Pilot config needs to be regenerated\n$files_to_be_updated\n" # | mail -s "$(basename $0) Pilot config needs to be regenerated" $notifytowhom
fi
cvmfs_server transaction 2>&1
if [ $? -ne 0 ] ; then
   echo DEBUG checking cvmfs_server list 
   cvmfs_server list 
   REPO_NAME=cms.cern.ch
   #cvmfs_suid_helper rw_umount $REPO_NAME
   #cvmfs_suid_helper rdonly_umount $REPO_NAME
   #cvmfs_suid_helper clear_scratch $REPO_NAME
   echo DEBUG checking     ls /var/spool/cvmfs/$REPO_NAME/in_transaction
   ls /var/spool/cvmfs/$REPO_NAME/in_transaction
   echo DEBUG newhash
   cat /srv/cvmfs/$REPO_NAME/.cvmfspublished | grep -a '^C.*' | tr -d C
   echo DEBUG oldhash
   grep CVMFS_ROOT_HASH= /var/spool/cvmfs/$REPO_NAME/client.local | cut -d= -f2
   cat /var/spool/cvmfs/$REPO_NAME/client.local
   #cvmfs_suid_helper rdonly_mount $REPO_NAME
   #cvmfs_suid_helper rw_mount $REPO_NAME

   printf "$(basename $0) ERROR cvmfs_server transaction failed\n$(cat $HOME/cvmfs_update_pilot_config.log | sed 's#%#%%#g')\nChecking ps\n$(ps auxwww | sed 's#%#%%#g' | grep $(/usr/bin/whoami) | grep -v grep)\n" | mail -s "$(basename $0) cvmfs_server transaction lock failed" $notifytowhom
   exit 1
fi
#[ $? -eq 0 ] || { printf "$(basename $0) ERROR cvmfs_server transaction lock failed\nTrying cvmfs_server transaction\n$(cvmfs_server transaction | sed 's#%#%%#g')\nChecking ps\n$(ps auxwww | sed 's#%#%%#g' | grep $(/usr/bin/whoami) | grep -v grep)\n" | mail -s "$(basename $0) cvmfs_server transaction lock failed" $notifytowhom ; exit 1 ; } ;
#export PYTHONPATH=$PYTHONPATH:$HOME/condor/lib/python

#for f in $files ; do
#  ls -al $HOME/tmp/$f /cvmfs/cms.cern.ch/glidein/$(basename $f)
#  diff $HOME/tmp/$f /cvmfs/cms.cern.ch/glidein/$(basename $f)
#  s=$?
#  if [ $s -ne 0 ] ; then
#     echo DEBUG copying $HOME/tmp/$f /cvmfs/cms.cern.ch/glidein/$(basename $f)
#     cp -pR $HOME/tmp/$f /cvmfs/cms.cern.ch/glidein/$(basename $f)
#  fi
#  #status=$(expr $status + $s)
#  #echo DEBUG diff status for $f status=$status
#  #[ $s -eq 0 ] && files_to_be_updated="$files_to_be_updated $(basename $f)"
#done

echo "$files_to_be_updated" | grep -q glidein_startup.sh
if [ $? -eq 0 ] ; then
   echo INFO updating glidein_startup.sh
   cp -pR $HOME/tmp/kestrel/src/glidein_startup.sh /cvmfs/cms.cern.ch/glidein/
fi
echo "$files_to_be_updated" | grep -q config_generated.ini
if [ $? -eq 0 ] ; then
   echo INFO updating config_generated.ini
   ./kestrel_pilot_config --write -o $HOME/tmp/config_generated.ini
   cp -pR $HOME/tmp/config_generated.ini /cvmfs/cms.cern.ch/glidein/
   [ $? -eq 0 ] || { printf "$(basename $0) ERROR kestrel_pilot_config --write failed\n" | mail -s "$(basename $0) kestrel_pilot_config --write failed" $notifytowhom ; cvmfs_server abort -f ; exit 1 ; } ;
   
fi
cvmfs_server publish
exit 0
