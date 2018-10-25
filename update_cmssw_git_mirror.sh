#!/bin/sh
# References 
# http://cms-sw.github.io/cmssw/advanced-usage.html#how_do_i_setup_a_local_mirror
# v=0.2.8
workdir=$HOME
notifytowhom=bockjoo@phys.ufl.edu
git_fetch_time_out=40
git_repack_time_out=40
ntry_git_fetch=1
ntry_git_repack=1

which_mirror=
if [ $# -eq 1 ] ; then
   which_mirror=$1
   which_mirror="."$which_mirror
fi
#CMSSW_MIRROR_PATH=/data1/phedex/t2/operations/git/cmssw.git #phedexb
#CMSSW_MIRROR_PATH=/cvmfs/cms.cern.ch/cmssw.git # cvmfs-cms
#CMSSW_MIRROR_PATH_OLD=/cvmfs/cms.cern.ch/cmssw.git.old # unused
#CMSSW_MIRROR_PATH_TMP=/cvmfs/cms.cern.ch/cmssw.git.tmp # unused

#CMSSW_MIRROR_PATH=/cvmfs/cms.cern.ch/cmssw.git.static # cvmfs-cms
#CMSSW_MIRROR_PATH_OLD=/cvmfs/cms.cern.ch/cmssw.git.static.old # unused
#CMSSW_MIRROR_PATH_TMP=/cvmfs/cms.cern.ch/cmssw.git.static.tmp # unused

CMSSW_MIRROR_PATH=/cvmfs/cms.cern.ch/cmssw.git${which_mirror} # cvmfs-cms
CMSSW_MIRROR_PATH_OLD=/cvmfs/cms.cern.ch/cmssw.git${which_mirror}.old # unused
CMSSW_MIRROR_PATH_TMP=/cvmfs/cms.cern.ch/cmssw.git${which_mirror}.tmp # unused

CMSSW_MIRROR_PATH_NEW=$HOME/cmssw.git # cvmfs-cms
CMSSW_MIRROR_PATH_BACKUP=$HOME/cmssw.git.old
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
create_local_workspace_patch
if [ ] ; then
if [ $(date +%d) -eq 12 ] ; then # Every month 12-th day
    echo DEBUG it is the 12-th day of the month
    if [ $(date +%H) == 03 ] ; then # 08 PM
       echo DEBUG it is 02
       if [ $(expr $(date +%M) + 0) -ge 2 ] ; then
          echo DEBUG running  create_local_workspace_patch_monthly
          create_local_workspace_patch_monthly
       fi
    fi
fi
fi # if [ ] ; then
exit 0
<<<<<<< HEAD
# The following is the old update script suggested by Andrew Melo
#printf "$(basename $0) Starting cvmfs_server transaction \n" | mail -s "cvmfs_server transaction started" $notifytowhom
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

if [ -f $HOME/stop.mirror.cmssw.git ] ; then
   printf "$(basename $0) -max-pack-size 20m failed \n" | mail -s "create_mirror_bare_cmssw_git_tmp git repack failed" $notifytowhom
   ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
   exit 1
fi

if [ -d $CMSSW_MIRROR_PATH ] ; then
   i=0
   i=$(expr $i + 1)
   echo INFO "[ $i ]" $CMSSW_MIRROR_PATH exists: Executing create_mirror_bare_cmssw_git_tmp Updating the mirror.....
   #read ans
   #result=$(create_mirror_bare_cmssw_git_tmp 2>&1)
   create_mirror_bare_cmssw_git_tmp > /tmp/create_mirror_bare_cmssw_git_tmp.log 2>&1
   status=$?
   cat /tmp/create_mirror_bare_cmssw_git_tmp.log
   if [ $status -ne 0 ] ; then
      error_message="ERROR failed: create_mirror_bare_cmssw_git_tmp"
      echo $error_message >> $HOME/stop.mirror.cmssw.git
      echo $error_message
      printf "$(basename $0) create_mirror_bare_cmssw_git_tmp failed \n$(cat /tmp/create_mirror_bare_cmssw_git_tmp.log)\n" | mail -s "$(basename $0) create_mirror_bare_cmssw_git_tmp failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      exit 1
   fi
   echo INFO "[ $i ]" $CMSSW_MIRROR_PATH_NEW created
   ls -al $CMSSW_MIRROR_PATH_NEW

   echo INFO "[ $i ]" copying the newest mirror to the cvmfs area: time rsync -arzuvp $CMSSW_MIRROR_PATH_NEW/ ${CMSSW_MIRROR_PATH}
   time rsync -arzuvp $CMSSW_MIRROR_PATH_NEW/ ${CMSSW_MIRROR_PATH}
   if [ $? -ne 0 ] ; then
      error_message="ERROR failed: time rsync -arzuvp $CMSSW_MIRROR_PATH_NEW/ ${CMSSW_MIRROR_PATH} failed"
      echo $error_message >> $HOME/stop.mirror.cmssw.git
      echo $error_message
      printf "$(basename $0) time rsync -arzuvp $CMSSW_MIRROR_PATH_NEW/ ${CMSSW_MIRROR_PATH} failed failed \n" | mail -s "$(basename $0) time rsync -arzuvp $CMSSW_MIRROR_PATH_NEW/ ${CMSSW_MIRROR_PATH} failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      exit 1
   fi


   echo INFO check $CMSSW_MIRROR_PATH
   echo INFO check $CMSSW_MIRROR_PATH_NEW
   #echo INFO cehck $CMSSW_MIRROR_PATH_BACKUP
   #exit 0

   i=$(expr $i + 1)
   echo INFO "[ $i ]" all move in place. Publishing the cvmfs now....

else
   echo DEBUG cloning bare mirror
   git clone --mirror --bare https://github.com/cms-sw/cmssw.git $CMSSW_MIRROR_PATH
   if [ $? -ne 0 ] ; then
      echo ERROR failed: git clone --mirror --bare https://github.com/cms-sw/cmssw.git $CMSSW_MIRROR_PATH
      printf "$(basename $0) git repack -a -d --max-pack-size 20m failed \n" | mail -s "$(basename $0) git clone failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      exit 1
   fi
   # [1] Split the chunk for the better cvmfs performance
   echo DEBUG splitting chunks
   ( cd $CMSSW_MIRROR_PATH
     #git repack -a -d --window-memory 10m --max-pack-size 20m
     git repack -a -d --max-pack-size 20m
     exit $?
   )
   status=$?

   if [ $status -ne 0 ] ; then
      echo ERROR failed: git repack -a -d --max-pack-size 20m
      printf "$(basename $0) git repack -a -d --max-pack-size 20m failed \n" | mail -s "$(basename $0) git repack failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      exit 1
   fi

   echo DEBUG git repack status=$status

   #[2] then, from time to time, I would execute this
   ( cd $CMSSW_MIRROR_PATH
     echo DEBUG executing git remote update origin
     git remote update origin
     status=$?
     if [ $status -ne 0 ] ; then
        echo ERROR failed: git remote update origin
        printf "$(basename $0) git remote update origin failed \n" | mail -s "$(basename $0) git remote update origin failed" $notifytowhom
        exit $status
     fi
     echo DEBUG executing git repack -a -d --max-pack-size 20m
     git repack -a -d --max-pack-size 20m
     exit $?
   )
   if [ $? -ne 0 ] ; then
      echo ERROR failed: git repack -a -d --max-pack-size 20m
      printf "$(basename $0) git repack -a -d --max-pack-size 20m failed\n" | mail -s "$(basename $0) git repack -a -d --max-pack-size 20m failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      exit 1
   fi

   echo DEBUG writing a README file
   echo /cvmfs/cms.cern.ch/cmssw.git: manually updated on demand > $(dirname $CMSSW_MIRROR_PATH)/README.cmssw.git
   echo "(See /cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates)" >> $(dirname $CMSSW_MIRROR_PATH)/README.cmssw.git
   echo /cvmfs/cms.cern.ch/cmssw.git.daily: daily updated >> $(dirname $CMSSW_MIRROR_PATH)/README.cmssw.git
   echo "(See /cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates)" >> $(dirname $CMSSW_MIRROR_PATH)/README.cmssw.git
   echo "Also," >> $(dirname $CMSSW_MIRROR_PATH)/README.cmssw.git
   echo Please refer to >> $(dirname $CMSSW_MIRROR_PATH)/README.cmssw.git
   echo http://cms-sw.github.io/cmssw/advanced-usage.html >> $(dirname $CMSSW_MIRROR_PATH)/README.cmssw.git
   
   echo DEBUG executing time cvmfs_server publish

fi

# echo "$(basename $CMSSW_MIRROR_PATH) noarch $(/bin/date +%s) $(/bin/date -u)" >> $updated_list

echo INFO executing time cvmfs_server publish

currdir=$(pwd)
cd
time cvmfs_server publish 2>&1 |  tee $HOME/cvmfs_server+publish.log
status=$?
cd $currdir

if [ $status -ne 0 ] ; then
   echo ERROR failed: cvmfs_server publish
   printf "$(basename $0) time cvmfs_server publish failed \n" | mail -s "$(basename $0) git repack -a -d --max-pack-size 20m" $notifytowhom
   ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
   exit 1
fi
#printf "$(basename $0) $(basename $0) $1 executed \n$(cat $HOME/update_cmssw_git_mirror.daily.log)\n" | mail -s "$(basename $0) $(basename $0) $1 executed" $notifytowhom
exit 0
=======
>>>>>>> 2d7800c5fe05812c3d8012af795ea40ab0365535

####### BEGIN Functions 12345
# Functions
function create_local_workspace_patch_monthly () {

WORKSPACE=/tmp/cvcms
GH_REPO=cmssw
MIRROR=/cvmfs/cms.cern.ch/${GH_REPO}.git
[ -d $WORKSPACE ] || mkdir -p $WORKSPACE
echo DEBUG inside create_local_workspace_patch_monthly 1
if [ -d ${MIRROR}.backup ] ; then
   printf "ERROR create_local_workspace_patch_monthly ${MIRROR}.backup exists " | mail -s "ERROR ${MIRROR}.backup exists" $notifytowhom
   return 1
fi
echo DEBUG inside create_local_workspace_patch_monthly 2
cvmfs_server transaction && mv  ${MIRROR}  ${MIRROR}.backup && cvmfs_server publish
if [ $? -ne 0 ] ; then
   printf "ERROR create_local_workspace_patch_monthly mv  ${MIRROR}  ${MIRROR}.backup failed" | mail -s "ERROR mv  ${MIRROR}  ${MIRROR}.backup failed" $notifytowhom
   return 1
fi
echo DEBUG inside create_local_workspace_patch_monthly 3
if [ ! -d ${MIRROR} ] ; then
   echo INFO creating ${MIRROR}
   cvmfs_server transaction && mkdir -p ${MIRROR} && cvmfs_server publish
fi
cd $WORKSPACE
echo INFO starting all over again
rm -rf ${GH_REPO}.git
echo INFO creating git config
git config --global http.postBuffer 209715200
echo INFO creating local worksapce patch
(git clone --bare https://github.com/cms-sw/${GH_REPO}.git && cvmfs_server transaction && rsync -a --delete ${GH_REPO}.git/ ${MIRROR}/  && cvmfs_server publish) || printf "ERROR create_local_workspace_patch failed\n" | mail -s "ERROR cmssw git create_local_workspace_patch failed" $notifytowhom
rm -rf ${GH_REPO}.git
printf "Warning all went well ${MIRROR}.backup should be removed" | mail -s "Warning remove ${MIRROR}.backup failed" $notifytowhom

}

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
git config --global http.postBuffer 209715200
echo INFO creating local worksapce patch
(git clone --bare https://github.com/cms-sw/${GH_REPO}.git && cvmfs_server transaction && rsync -a --delete ${GH_REPO}.git/ ${MIRROR}/  && cvmfs_server publish) || printf "ERROR create_local_workspace_patch failed\n" | mail -s "ERROR cmssw git create_local_workspace_patch failed" $notifytowhom
rm -rf ${GH_REPO}.git

}

function create_mirror_bare_cmssw_git_tmp () {
   #[ -d $CMSSW_MIRROR_PATH_NEW ] && return 1

   if [ ! -d $CMSSW_MIRROR_PATH_NEW ] ; then
      echo DEBUG cloning bare mirror
      git clone --mirror --bare https://github.com/cms-sw/cmssw.git $CMSSW_MIRROR_PATH_NEW
      if [ $? -ne 0 ] ; then
         echo ERROR failed: git clone --mirror --bare https://github.com/cms-sw/cmssw.git $CMSSW_MIRROR_PATH_NEW
         printf "create_mirror_bare_cmssw_git_tmp git repack -a -d --max-pack-size 20m failed \n" | mail -s "create_mirror_bare_cmssw_git_tmp git clone failed" $notifytowhom
         return 1
      fi
   fi
   echo DEBUG splitting chunks
   ( echo INFO cd $CMSSW_MIRROR_PATH_NEW
     cd $CMSSW_MIRROR_PATH_NEW
     #if [ ] ; then
     #   git repack -a -d --max-pack-size 20m
     #   status=$?
     #else
     status=0
     itry=0
     while [ $itry -lt $ntry_git_fetch ] ; do
        itry=$(expr $itry + 1)
        echo INFO executing git fetch
        git fetch >& $HOME/git.fetch.log &
        theps=$!
        echo INFO executed git fetch with the pid=$theps
        timeout_encountered=0
        i=0
        while : ; do
           #echo DEBUG Doing check if rpm -qa process is ended $i
           if [ $i -gt $git_fetch_time_out ] ; then
            ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
            [ $? -eq 0 ] && { kill $theps ; echo Warning git fetch $theps killed ; } ;
            timeout_encountered=1
            break
          fi
          ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
          [ $? -eq 0 ] || { echo INFO git fetch $theps finished within time at itry=$itry ; break ; } ;
          i=$(expr $i + 1)
          sleep 1m
        done
        wait $theps
        status=$?
        echo DEBUG timeout_encountered=$timeout_encountered 

        if [ $timeout_encountered -eq 0 ] ; then
           if [ $status -eq 0 ] ; then
              echo INFO git fetch completed breaking out of the while loop 
              break
           fi
        else
           git_remote_https_process_m_s=$(ps -efL | grep git-remote-https | grep -v grep | awk '{print $2"+"$3}')
           git_remote_https_processes=
           children_procs=
           for git_remote_https_process_m in $git_remote_https_process_m_s ; do
             if [ $(echo $git_remote_https_process_m | cut -d+ -f2) -eq 1 ] ; then
                 git_remote_https_process=$(echo $git_remote_https_process_m | cut -d+ -f1)
                 children_proc=$(pstree -a -l -p $git_remote_https_process | cut -d, -f2 | awk '{print $1}' | sed 's#)##g' | sed 's#(##g' | grep -v $git_remote_https_process)
                 git_remote_https_processes="$git_remote_https_processes $git_remote_https_process"
                 children_procs="$children_procs $children_proc"
              fi
           done
           children_procs=$(echo $children_procs)
           printf "ERROR create_mirror_bare_cmssw_git_tmp timeout is encountered while git fetch\n$(cat $HOME/git.fetch.log )\nProcesses to be killed: $git_remote_https_processes + $children_procs\nExecuting kill $git_remote_https_processes $children_procs\n" | mail -s "ERROR itry=$itry create_mirror_bare_cmssw_git_tmp git fetch timeout" $notifytowhom
           [ "x$(echo $(echo $git_remote_https_processes $children_procs))" == "x" ] || { echo Warning kill $git_remote_https_processes $children_procs ; kill $git_remote_https_processes $children_procs ; } ;
           sleep 5m
           continue # return 1
        fi
        if [ $status -eq 0 ] ; then
           break
        else
           printf "ERROR create_mirror_bare_cmssw_git_tmp git fetch failed\n$(cat $HOME/git.fetch.log )\n" | mail -s "ERROR itry=$itry create_mirror_bare_cmssw_git_tmp git fetch failed" $notifytowhom
           sleep 5m
           continue # return 1
        fi
     done

     if [ $status -eq 0 ] ; then
        printf "INFO create_mirror_bare_cmssw_git_tmp git fetch successful\n$(cat $HOME/git.fetch.log )\n" | mail -s "INFO Success: itry=$itry create_mirror_bare_cmssw_git_tmp git fetch " $notifytowhom
     else
        exit $status
     fi

     itry=0
     while [ $itry -lt $ntry_git_repack ] ; do
        itry=$(expr $itry + 1)
        echo INFO executing git repack --max-pack-size 64m
        git repack --max-pack-size 64m  >& $HOME/git.repack.log & #CVMFS splits files into 64 meg blocks
        theps=$!
        echo INFO executed git repack --max-pack-size 64m with the pid=$theps
        timeout_encountered=0
        i=0
        while : ; do
           #echo DEBUG Doing check if rpm -qa process is ended $i
           if [ $i -gt $git_repack_time_out ] ; then
            ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
            [ $? -eq 0 ] && { kill $theps ; echo Warning git repack $theps killed ; } ;
            timeout_encountered=1
            break
          fi
          ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
          [ $? -eq 0 ] || { echo INFO git repack $theps finished within time ; break ; } ;
          i=$(expr $i + 1)
          sleep 1m
        done
        wait $theps
        status=$?
        if [ $timeout_encountered -eq 0 ] ; then
           if [ $status -eq 0 ] ; then
              echo INFO git repack completed breaking out of while loop
              break
           fi
        else
           printf "ERROR create_mirror_bare_cmssw_git_tmp timeout is encountered while git repack\n$(cat $HOME/git.repack.log)\n" | mail -s "ERROR itry=$itry create_mirror_bare_cmssw_git_tmp git repack timeout" $notifytowhom
           continue # return 1
        fi
        if [ $status -eq 0 ] ; then
           break
        else
           printf "ERROR create_mirror_bare_cmssw_git_tmp git repack failed\n$(cat $HOME/git.repack.log)\n" | mail -s "ERROR itry=$itry create_mirror_bare_cmssw_git_tmp git repack failed" $notifytowhom
           continue # return 1
        fi
     done
     #fi
     exit $status
   )
   status=$?

   if [ $status -ne 0 ] ; then
      #echo ERROR failed: git repack -a -d --max-pack-size 20m
      #printf "create_mirror_bare_cmssw_git_tmp git repack -a -d --max-pack-size 20m failed \n" | mail -s "create_mirror_bare_cmssw_git_tmp git repack failed" $notifytowhom
      echo ERROR failed: git fetch git repack --max-pack-size 64m
      printf "create_mirror_bare_cmssw_git_tmp git fetch git repack --max-pack-size 64m failed \n$(cat $HOME/git.repack.log)\n" | mail -s "create_mirror_bare_cmssw_git_tmp git repack failed" $notifytowhom
      return 1
   fi

   echo DEBUG git repack status=$status

   return 0
}

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
####### ENDIN Functions 12345
