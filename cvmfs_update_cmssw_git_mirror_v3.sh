#!/bin/sh
# References 
# http://cms-sw.github.io/cmssw/advanced-usage.html#how_do_i_setup_a_local_mirror
# https://gist.github.com/PerilousApricot/02ff6d127d64948ec4348ea690ff4a5f
# v=0.0.1
workdir=$HOME
notifytowhom=bockjoo@phys.ufl.edu
updated_list=/cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates
functions=$workdir/$(basename $0 | sed "s#\.sh##g")-functions # .$(date -u +%s)
perl -n -e 'print if /^####### BEGIN Functions 12345/ .. /^####### ENDIN Functions 12345/' < $0 | grep -v "Functions 12345" > $functions
if [ ! -f $functions ] ; then
   echo ERROR $functions does not exist
   printf "$(basename $0) ERROR failed to create $functions\nfunctions does not exist\n" | mail -s "ERROR failed to create the functions" $notifytowhom
   exit 1
fi
source $functions
rm -f $functions

# Doing the one suggested by Shahzad: I switched to this one from Andrew's old prescription for some reason
#                                     ( I think some fetch errors that I have been seeing )
echo INFO Doing the one suggested by Shahzad
#create_local_workspace_patch
# repack suggested by Andrew Melo added
create_local_workspace_patch_month_and_day
exit $?

####### BEGIN Functions 12345
# Functions
function create_local_workspace_patch () {

WORKSPACE=/tmp/cvcms
GH_REPO=cmssw
MIRROR=/cvmfs/cms.cern.ch/${GH_REPO}.git.daily
[ -d $WORKSPACE ] || mkdir -p $WORKSPACE
if [ ! -d ${MIRROR} ] ; then
   echo INFO creating ${MIRROR}
   cvmfs_server transaction && mkdir -p ${MIRROR} && cvmfs_server publish
fi
cd $WORKSPACE
echo INFO starting all over again
rm -rf ${GH_REPO}.git
echo INFO creating git config
#git config --global http.postBuffer 209715200
git config --global http.postBuffer 524288000
echo INFO creating local worksapce patch
(git clone --bare https://github.com/cms-sw/${GH_REPO}.git && cvmfs_server transaction && rsync -a --delete ${GH_REPO}.git/ ${MIRROR}/  && cvmfs_server publish) || printf "ERROR create_local_workspace_patch failed\n" | mail -s "ERROR cmssw git create_local_workspace_patch failed" $notifytowhom
rm -rf ${GH_REPO}.git

}

function create_local_workspace_patch_month_and_day () {

WORKSPACE=/tmp/cvcms
GH_REPO=cmssw
MIRROR=/cvmfs/cms.cern.ch/${GH_REPO}.git.daily
MIRROR_MONTHLY=/cvmfs/cms.cern.ch/${GH_REPO}.git
[ -d $WORKSPACE ] || mkdir -p $WORKSPACE
if [ ! -d ${MIRROR} ] ; then
   echo INFO creating ${MIRROR}
   cvmfs_server transaction && mkdir -p ${MIRROR} && cvmfs_server publish
fi
if [ ! -d ${MIRROR_MONTHLY} ] ; then
   echo INFO creating ${MIRROR_MONTHLY}
   cvmfs_server transaction && mkdir -p ${MIRROR_MONTHLY} && cvmfs_server publish
fi

# Use the latest git binary built from source. Otherwise git fetch does not work on SL6
export PATH=/home/cvcms/git/bin:$PATH

#cd $WORKSPACE

if [[ ! -d $MIRROR_MONTHLY ]]; then
   cd $WORKSPACE
   rm -rf ${GH_REPO}.git
   (
    #git clone --bare --mirror https://github.com/cms-sw/cmssw $MONTH_PATH
    echo INFO git clone --bare --mirror https://github.com/cms-sw/${GH_REPO}.git
    git clone --bare --mirror https://github.com/cms-sw/${GH_REPO}.git
    [ $? -eq 0 ] || exit 1
    # GC can leave dangling objects
    #pushd $MONTH_PATH
    pushd ${GH_REPO}.git
    git config --global gc.auto 0
    [ $? -eq 0 ] || exit 2
    git repack -a -d --window=50 --max-pack-size=64M
    [ $? -eq 0 ] || exit 3
    popd
    cvmfs_server transaction && rsync -a --delete ${GH_REPO}.git/ ${MIRROR_MONTHLY}/  && cvmfs_server publish
    exit $?
   ) || { printf "ERROR initial create_local_workspace_patch_month_and_day failed\n" | mail -s "ERROR initial cmssw git create_local_workspace_patch_month_and_day failed" $notifytowhom ; rm -rf ${GH_REPO}.git ; return 1 ; } ;
   rm -rf ${GH_REPO}.git
fi

#echo INFO starting all over again

# Monthly
if [ $(date +%d) -eq 12 ] ; then # Every month 12-th day
  cd $WORKSPACE
  rm -rf ${GH_REPO}.git
  (
   echo INFO start from last month: /bin/cp -a /cvmfs/cms.cern.ch/${GH_REPO}.git ${GH_REPO}.git
   /bin/cp -a ${MIRROR_MONTHLY} ${GH_REPO}.git
   [ $? -eq 0 ] || exit 1
   pushd ${GH_REPO}.git

   git config --global http.postBuffer 209715200
   echo INFO git fetch
   git fetch #-v --progress
   [ $? -eq 0 ] || exit 2

   echo INFO git repack -a -d --window=50 --max-pack-size=64M
   git repack -a -d --window=50 --max-pack-size=64M
   [ $? -eq 0 ] || exit 3
   popd
   echo INFO cvmfs_server transaction \&\& rsync -a --delete ${GH_REPO}.git/ ${MIRROR_MONTHLY}/  \&\& cvmfs_server publish
   cvmfs_server transaction && rsync -a --delete ${GH_REPO}.git/ ${MIRROR_MONTHLY}/  && cvmfs_server publish
   exit $? 
  ) || { printf "ERROR create_local_workspace_patch_month_and_day for monthly failed\n" | mail -s "ERROR cmssw git create_local_workspace_patch_month_and_day for monthly failed" $notifytowhom ; rm -rf ${GH_REPO}.git ; return 1 ; } ;
  rm -rf ${GH_REPO}.git
fi

# Daily
# Build the daily repo off the monthly repo to ensure the base doesnt 
# change. Since the file content is the same, CVMFS also will only store
# the underlying bytes once

cd $WORKSPACE
echo INFO starting all over again by rm -f $(pwd)/${GH_REPO}.git
rm -rf ${GH_REPO}.git
(
  echo INFO /bin/cp -a /cvmfs/cms.cern.ch/${GH_REPO}.git ${GH_REPO}.git
  /bin/cp -a ${MIRROR_MONTHLY} ${GH_REPO}.git
  [ $? -eq 0 ] || exit 1
  pushd ${GH_REPO}.git

  git config --global http.postBuffer 209715200

  echo INFO git fetch
  git fetch
  [ $? -eq 0 ] || exit 2

  echo INFO git repack --max-pack-size=64M
  git repack --max-pack-size=64M
  [ $? -eq 0 ] || exit 3
  popd
  # Looks like everything went well will publish
  echo INFO cvmfs_server transaction \&\& rsync -a --delete ${GH_REPO}.git/ ${MIRROR}/  \&\& cvmfs_server publish
  cvmfs_server transaction && rsync -a --delete ${GH_REPO}.git/ ${MIRROR}/  && cvmfs_server publish
  exit $? 
) || { printf "ERROR create_local_workspace_patch_month_and_day failed\n" | mail -s "ERROR cmssw git create_local_workspace_patch_month_and_day failed" $notifytowhom ; rm -rf ${GH_REPO}.git ; return 1 ; } ;
rm -rf ${GH_REPO}.git
return 0
}
####### ENDIN Functions 12345
