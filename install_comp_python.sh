#!/bin/sh
# version=0.1.1
install_comp_python_version=0.1.1
###################################################################
#                                                                 #
export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
#export VO_CMS_SW_DIR=$HOME
export RELEASE=2.6.8-comp9
#export RELEASE=3.3.0.pre3-comp
#export RELEASE=3.3.0.rc1-comp2
#export REPO=comp.pre.bbockelm
export REPO=comp.pre
export SCRAM_ARCH=slc6_amd64_gcc481
notifytowhom=bockjoo@phys.ufl.edu
RPMS=http://cmsrep.cern.ch/cmssw/${REPO}/RPMS/${SCRAM_ARCH}/

if [ $# -gt 0 ] ; then
   if [ "x$1" != "x-" ] ; then
      export VO_CMS_SW_DIR=$1
   fi
fi
if [ $# -gt 1 ] ; then
   if [ "x$2" != "x-" ] ; then
      export RELEASE=$2
   fi
fi
if [ $# -gt 2 ] ; then
   if [ "x$3" != "x-" ] ; then
      export REPO=$3
   fi
fi
if [ $# -gt 3 ] ; then
   if [ "x$4" != "x-" ] ; then
      export SCRAM_ARCH=$4
   fi
fi

RPMS=http://cmsrep.cern.ch/cmssw/${REPO}/RPMS/${SCRAM_ARCH}/

echo INFO $(basename $0) $VO_CMS_SW_DIR $RELEASE ${REPO} $RPMS
updated_list=$VO_CMS_SW_DIR/cvmfs-cms.cern.ch-updates
#export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
cvmfs_server_name=$(grep cvmfs_server_name= $HOME/cron_install_cmssw.config | grep -v \# | cut -d= -f2)
cvmfs_server_name=$(eval echo $cvmfs_server_name)

uname -a | grep -q "$cvmfs_server_name"
if [ $? -eq 0 ] ; then
   cvmfs_server_yes=yes
fi

uname -a | grep -q vocms10
if [ $? -eq 0 ] ; then
   workdir=$HOME
   cvmfs_server_yes=no
fi


#
export MYINSTALLAREA=$VO_CMS_SW_DIR/COMP
#
#                                                                 #
###################################################################
grep -q "COMP+python+$RELEASE " $updated_list
if [ $? -eq 0 ] ; then
   echo Warning COMP+python $RELEASE installed according to $updated_list
   exit 0
fi


# pre-check
echo "$SCRAM_ARCH" | grep -q slc[0-9]
if [ $? -ne 0 ] ; then
   echo ERROR SCRAM_ARCH=$SCRAM_ARCH does not start with slc
   printf "$(basename $0) SCRAM_ARCH=$SCRAM_ARCH does not start with slc\n" | mail -s "SCRAM_ARCH=$SCRAM_ARCH ERROR" $notifytowhom
   exit 1
fi

i=0
if [ -d $MYINSTALLAREA ] ; then
   echo INFO "[$i]" $MYINSTALLAREA exists
else
   echo INFO "[$i]" creates $MYINSTALLAREA
    mkdir -p $MYINSTALLAREA
fi
   
i=$(expr $i + 1)
# Check if bootstrap is needed for $arch
#ls -al $MYINSTALLAREA/$SCRAM_ARCH/external/apt/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null
ls -al $MYINSTALLAREA/$SCRAM_ARCH/external/rpm/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null
if [ $? -eq 0 ] ; then
   echo INFO "[$i]" bootstratp unnecessary for ${SCRAM_ARCH} in COMP+python
   #exit 0
else
   echo INFO "[$i]" downloading bootstrap.sh
   wget -O $MYINSTALLAREA/bootstrap.sh http://cmsrep.cern.ch/cmssw/$REPO/bootstrap.sh
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap.sh download failed
      printf "install_comp_python.sh failed to download http://cmsrep.cern.ch/cmssw/$REPO/bootstrap.sh\n" | mail -s "ERROR: install_comp_python.sh failed to download" $notifytowhom
      exit 1
   fi

   i=$(expr $i + 1)
   echo INFO "[$i]" executing bootstrap.sh
   sh -x $MYINSTALLAREA/bootstrap.sh -architecture $SCRAM_ARCH -path $MYINSTALLAREA -repository $REPO setup
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap.sh failed
      printf "install_comp_python.sh failed to download http://cmsrep.cern.ch/cmssw/$REPO/bootstrap.sh\n" | mail -s "ERROR: install_comp_python.sh failed to download" $notifytowhom
      exit 1
   fi
fi

ls -al $MYINSTALLAREA/$SCRAM_ARCH/external/apt/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null
if [ $? -ne 0 ] ; then
   echo ERROR strange $MYINSTALLAREA/$SCRAM_ARCH/external/apt/*/etc/profile.d/init.sh does not exist
   printf "install_comp_python.sh strange $MYINSTALLAREA/$SCRAM_ARCH/external/apt/*/etc/profile.d/init.sh does not exist\n" | mail -s "ERROR: strange init.sh does not exist"  $notifytowhom
   exit 1
fi

source $(ls -t $MYINSTALLAREA/$SCRAM_ARCH/external/apt/*/etc/profile.d/init.sh | head -1)
source $(ls -t $MYINSTALLAREA/$SCRAM_ARCH/external/curl/*/etc/profile.d/init.sh | head -1)

i=$(expr $i + 1)
echo INFO "[$i]" executing apt-get upgrade
apt-get --assume-yes upgrade
status=$?
if [ $status -ne 0 ] ; then
   echo ERROR apt-get upgrade failed
   exit 1
fi

i=$(expr $i + 1)
echo INFO "[$i]" executing apt-get update
apt-get --assume-yes update
status=$?
if [ $status -ne 0 ] ; then
   echo ERROR apt-get update failed
   exit 1
fi

i=$(expr $i + 1)
echo INFO "[$i]" executing apt-get install external+python+$RELEASE
apt-get install --assume-yes external+python+$RELEASE
status=$?
if [ $status -ne 0 ] ; then
   echo ERROR apt-get install external+python+$RELEASE failed
   exit 1
fi

if [ "x$cvmfs_server_yes" == "xyes" ] ; then
   grep -q "COMP+python+$RELEASE " $updated_list
   if [ $? -eq 0 ] ; then
     echo Warning COMP+python $RELEASE is already in the $updated_list
   else
     echo INFO adding COMP+python $RELEASE to $updated_list
     echo COMP+python+$RELEASE $(/bin/date +%s) $(/bin/date -u) >> $updated_list
   fi
   i=$(expr $i + 1)
   echo INFO "[$i]" Check $updated_list for $RELEASE

   echo INFO adding nested catalog
   j=0
   nslc=$(echo $MYINSTALLAREA/slc* | wc -w)
   for thedir in $MYINSTALLAREA/slc* ; do
      [ "x$thedir" == "x$MYINSTALLAREA/slc*" ] && break
      [ -d $thedir ] || continue
      j=$(expr $j + 1)
      ls -al $thedir/.cvmfscatalog 2>/dev/null 1>/dev/null ;
      if [ $? -eq 0 ] ; then
         echo INFO "[ $j / $nslc ]" $thedir/.cvmfscatalog exists
      else
         echo INFO "[ $j / $nslc ]" creating $thedir/.cvmfscatalog
         touch $thedir/.cvmfscatalog
      fi


      i=$(expr $i + 1)
      echo INFO "[$i]" Check $thedir/.cvmfscatalog
      echo INFO now further doing $MYINSTALLAREA/"<scram_arch>"/external/python/"<rel>"/.cvmfscatalog
      for rel_dir in $thedir/external/python/* ; do
          [ "x$rel_dir" == "x$thedir/external/python/*" ] && break
          [ -d $rel_dir ] || continue
          ls -al $rel_dir/.cvmfscatalog 2>/dev/null 1>/dev/null ;
          if [ $? -eq 0 ] ; then
             echo INFO $rel_dir/.cvmfscatalog exists
          else
             echo INFO creating $rel_dir/.cvmfscatalog
             touch $rel_dir/.cvmfscatalog
          fi
      done
   done
   #echo INFO publishing cvmfs
   #publish_cmssw_cvmfs
   #echo INFO publishing the installation in the cvmfs
   #time cvmfs_server publish 2>&1 | tee $HOME/cvmfs_server+publish+crabclient+install.log
   #currdir=$(pwd)
   #cd
   #time cvmfs_server publish 2>&1 |  tee $HOME/cvmfs_server+publish+COMP+python.log
   #cd $currdir
   #status=$?
   #if [ $status -eq 0 ] ; then
   #   printf "$(basename $0) cvmfs_server_publish OK \n$(cat $HOME/cvmfs_server+publish+COMP+python.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish for COMP python install OK" $notifytowhom
   #else
   #   echo ERROR failed cvmfs_server publish
   #   printf "$(basename $0) cvmfs_server publish failed\n$(cat $HOME/cvmfs_server+publish+COMP+python.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish failed" $notifytowhom
   #   ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
   #   return 1
   #fi

   #echo INFO publishing 
fi # if [ "x$cvmfs_server_yes" == "xyes" ] ; then
#fi # if $updated_list exists thus cvmfs server

exit $status
