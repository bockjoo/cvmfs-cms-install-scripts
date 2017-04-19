#!/bin/sh
# 0.1.0 : Request from Nicolor Magini
# version=0.1.0
install_phedexagents_version=0.1.0
###################################################################

export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch

export RELEASE=4.2.0pre3
export REPO=comp
export SCRAM_ARCH=slc6_amd64_gcc493
cvmfs_server_name=$(grep cvmfs_server_name= $HOME/cron_install_cmssw.config | grep -v \# | cut -d= -f2)
cvmfs_server_name=$(eval echo $cvmfs_server_name)
notifytowhom=$(grep notifytowhom= $HOME/cron_install_cmssw.config | grep -v \# | cut -d= -f2)
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

uname -a | grep -q "$cvmfs_server_name"
if [ $? -eq 0 ] ; then
   cvmfs_server_yes=yes
fi

#
export MYTESTAREA=$VO_CMS_SW_DIR/phedex # ~/tmp/phedexagents # or wherever#
#
#                                                                 #
###################################################################
grep -q "PhEDExAgents $RELEASE ${SCRAM_ARCH}" $updated_list
if [ $? -eq 0 ] ; then
   echo Warning PhEDExAgents $RELEASE ${SCRAM_ARCH} installed according to $updated_list
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
if [ -d $MYTESTAREA ] ; then
   echo INFO "[$i]" $MYTESTAREA exists
else
   echo INFO "[$i]" creates $MYTESTAREA
    mkdir -p $MYTESTAREA
fi
   
i=$(expr $i + 1)
# Check if bootstrap is needed for $arch
ls -al $MYTESTAREA/$SCRAM_ARCH/external/rpm/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null
if [ $? -eq 0 ] ; then
   echo INFO "[$i]" bootstratp unnecessary for ${SCRAM_ARCH} in phedexagents
else
   printf "$(basename $0) downloading bootstrap for $SCRAM_ARCH \n" | mail -s "$(basename $0) downloading bootstrap" $notifytowhom
   echo INFO "[$i]" downloading bootstrap.sh
   wget -O $MYTESTAREA/bootstrap.sh http://cmsrep.cern.ch/cmssw/$REPO/bootstrap.sh
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap.sh download failed
      exit 1
   fi

   i=$(expr $i + 1)
   echo INFO "[$i]" executing bootstrap.sh
   sh -x $MYTESTAREA/bootstrap.sh -architecture $SCRAM_ARCH -path $MYTESTAREA -repository $REPO setup
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap.sh failed
      exit 1
   fi
fi

CMSPKG="$MYTESTAREA/common/cmspkg -a $SCRAM_ARCH"
if [ -f $MYTESTAREA/common/cmspkg ] ; then
   echo INFO We use cmspkg
else
   (
    cd /tmp
    echo INFO downloading cmspkg.py
    wget -O cmspkg.py https://raw.githubusercontent.com/cms-sw/cmspkg/production/client/cmspkg.py

    [ $? -eq 0 ] || { echo ERROR wget cmspkg.py failed ; rm -f cmspkg.py ; cd - ; exit 1 ; } ;

    python cmspkg.py --architecture $SCRAM_ARCH --path $MYTESTAREA --repository comp setup
    status=$?
    [ -f $MYTESTAREA/common/cmspkg ] || { echo ERROR cmspkg is not installed ; rm -f cmspkg.py ; exit 1 ; } ;
    rm -f cmspkg.py
    cd
    exit $status
   )
   [ $? -eq 0 ] || { printf "$(basename $0) $MYTESTAREA/common/cmspkg does not exist\nUse \nsource $HOME/cron_install_cmssw-functions\ndeploy_cmspkg /cvmfs/cms.cern.ch/phedexagents slc6_amd64_gcc494 comp\n" | mail -s "ERROR: $MYTESTAREA/common/cmspkg does not exist" $notifytowhom ; exit 1 ; } ;
fi

#
#source $(ls -t $MYTESTAREA/$SCRAM_ARCH/external/curl/*/etc/profile.d/init.sh | head -1) # cvmfs_server

i=$(expr $i + 1)
echo INFO "[$i]" executing $CMSPKG -y upgrade # apt-get upgrade
$CMSPKG -y upgrade # apt-get --assume-yes upgrade
status=$?
if [ $status -ne 0 ] ; then
   echo ERROR $CMSPKG -y upgrade upgrade failed
   exit 1
fi

# Check if mutex error exists
echo INFO check if mutex error exists
# First pick the right rpm
rpm_init_env=$(ls -t $MYTESTAREA/${SCRAM_ARCH}/external/rpm/*/etc/profile.d/init.sh | head -1)
if [ -f $rpm_init_env ] ; then
   source $rpm_init_env
else
   echo Warning $rpm_init_env does not exist
fi
echo INFO first which rpm"?: " $(which rpm) 
rpm -qa --queryformat '%{NAME} %{RELEASE}' > $HOME/logs/rpm_qa_NAME_RELEASE.phedex.${SCRAM_ARCH}.log 2>&1
grep "unable to allocate memory for mutex" $HOME/logs/rpm_qa_NAME_RELEASE.phedex.${SCRAM_ARCH}.log | grep -q "resize mutex region"
if [ $? -eq 0 ] ; then
      grep -q "mutex_set_max 10000000" $MYTESTAREA/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
      if [ $? -ne 0 ] ; then
         echo INFO adding mutex_set_max 1000000 to $MYTESTAREA/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
         echo mutex_set_max 10000000 >> $MYTESTAREA/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
         echo INFO rebuilding the DB
         rpmdb --define "_rpmlock_path $MYTESTAREA/${SCRAM_ARCH}/var/lib/rpm/lock" --rebuilddb --dbpath $MYTESTAREA/${SCRAM_ARCH}/var/lib/rpm 2>&1 | tee $HOME/logs/rpmdb_rebuild.phedex.${SCRAM_ARCH}.log
      fi
fi    

i=$(expr $i + 1)
echo INFO "[$i]" executing $CMSPKG update # apt-get update
$CMSPKG update 2>&1 # apt-get --assume-yes update
status=$?
if [ $status -ne 0 ] ; then
   echo ERROR $CMSPKG update failed
   exit 1
fi

i=$(expr $i + 1)
echo INFO "[$i]" executing $CMSPKG -y install cms+PHEDEX+$RELEASE
$CMSPKG -y install cms+PHEDEX+$RELEASE > $HOME/logs/cmspkg_install_cms_PHEDEX_${SCRAM_ARCH}_$RELEASE.log 2>&1
status=$?
grep "unable to allocate memory for mutex" $HOME/logs/cmspkg_install_cms_PHEDEX_${SCRAM_ARCH}_$RELEASE.log | grep -q "resize mutex region"
if [ $? -eq 0 ] ; then
      grep -q "mutex_set_max 10000000" $MYTESTAREA/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
      if [ $? -ne 0 ] ; then
         echo INFO adding mutex_set_max 1000000 to $MYTESTAREA/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
         echo mutex_set_max 10000000 >> $MYTESTAREA/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
         echo INFO rebuilding the DB
         rpmdb --define "_rpmlock_path $MYTESTAREA/${SCRAM_ARCH}/var/lib/rpm/lock" --rebuilddb --dbpath $MYTESTAREA/${SCRAM_ARCH}/var/lib/rpm 2>&1 | tee $HOME/logs/rpmdb_rebuild.phedex.${SCRAM_ARCH}.log
      fi
      if [ $status -ne 0 ] ; then
         echo INFO "[$i]" executing $CMSPKG -y install cms+PHEDEX+$RELEASE again after rebuilding the rpmdb after the mutex error
         $CMSPKG -y install cms+PHEDEX+$RELEASE > $HOME/logs/cmspkg_install_cms_PHEDEX_${SCRAM_ARCH}_$RELEASE.log 2>&1
         status=$?
      fi
fi    

cat $HOME/logs/cmspkg_install_cms_PHEDEX_${SCRAM_ARCH}_$RELEASE.log

if [ $status -ne 0 ] ; then
   echo ERROR $CMSPKG -y install cms+PHEDEX+$RELEASE failed
   echo Exiting from $(basename $0)
   exit 1
fi

i=$(expr $i + 1)
echo INFO "[$i]" succefully executed $CMSPKG -y install cms+PHEDEX+$RELEASE

echo INFO checking $SCRAM_ARCH

if [ "x$cvmfs_server_yes" == "xyes" ] ; then
   grep -q "PhEDExAgents $RELEASE ${SCRAM_ARCH}" $updated_list
   if [ $? -eq 0 ] ; then
     echo Warning PhEDExAgents $RELEASE ${SCRAM_ARCH} is already in the $updated_list
   else
     echo INFO adding PhEDExAgents $RELEASE ${SCRAM_ARCH} to $updated_list
     echo PhEDExAgents $RELEASE ${SCRAM_ARCH} $(/bin/date +%s) $(/bin/date -u) >> $updated_list
   fi
   i=$(expr $i + 1)
   echo INFO "[$i]" Check $updated_list for $RELEASE

   echo INFO adding nested catalog
   j=0
   nslc=$(echo $MYTESTAREA/slc* | wc -w)
   for thedir in $MYTESTAREA/slc* ; do
      [ "x$thedir" == "x$MYTESTAREA/slc*" ] && break
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
      echo INFO now further doing $phedexagents_rel_dir/.cvmfscatalog
      for phedexagents_rel_dir in $thedir/cms/PHEDEX/* ; do
          [ "x$phedexagents_rel_dir" == "x$thedir/cms/PHEDEX/*" ] && break
          [ -d $phedexagents_rel_dir ] || continue
          ls -al $phedexagents_rel_dir/.cvmfscatalog 2>/dev/null 1>/dev/null ;
          if [ $? -eq 0 ] ; then
             echo INFO $phedexagents_rel_dir/.cvmfscatalog exists
          else
             echo INFO creating $phedexagents_rel_dir/.cvmfscatalog
             touch $phedexagents_rel_dir/.cvmfscatalog
          fi
      done
   done
   echo INFO publishing cvmfs
   echo INFO publishing the installation in the cvmfs
   currdir=$(pwd)
   cd
   time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish+phedexagents+install.log
   cd $currdir
   status=$?
   if [ $status -eq 0 ] ; then
      printf "$(basename $0) cvmfs_server_publish OK \n$(cat $HOME/logs/cvmfs_server+publish+phedexagents+install.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish for PHEDEX install OK" $notifytowhom
   else
      echo ERROR failed cvmfs_server publish
      printf "$(basename $0) cvmfs_server publish failed\n$(cat $HOME/logs/cvmfs_server+publish+phedexagents+install.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      exit 1
   fi

   #echo INFO publishing 
fi # if [ "x$cvmfs_server_yes" == "xyes" ] ; then


exit $status
