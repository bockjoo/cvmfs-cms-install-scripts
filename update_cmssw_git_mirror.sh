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

# Doing the one suggested by Shahzad
echo INFO Doing the one suggested by Shahzad
create_local_workspace_patch
exit 0

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
