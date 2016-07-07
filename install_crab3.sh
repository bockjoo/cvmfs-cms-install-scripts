#!/bin/sh
# 0.2.6 : curl
# 0.2.7 : clean up
# 0.2.8 : fix crab_init.sh and crab_init.csh linking
# version=0.2.8
install_crab3_version=0.2.8
###################################################################
#                                                                 #
export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
#export VO_CMS_SW_DIR=$HOME
export RELEASE=3.3.0.pre3-comp2
export RELEASE=3.3.0.pre3-comp
export RELEASE=3.3.0.rc1-comp2
export REPO=comp.pre.bbockelm
export REPO=comp
export SCRAM_ARCH=slc5_amd64_gcc461
notifytowhom=bockjoo@phys.ufl.edu
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
#export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch

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
export MYTESTAREA=$VO_CMS_SW_DIR/crab3 # ~/tmp/crab3 # or wherever#
#
#                                                                 #
###################################################################
grep -q "crabclient $RELEASE ${SCRAM_ARCH}" $updated_list
if [ $? -eq 0 ] ; then
   echo Warning crabclient $RELEASE ${SCRAM_ARCH} installed according to $updated_list
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
ls -al $MYTESTAREA/$SCRAM_ARCH/external/apt/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null
if [ $? -eq 0 ] ; then
   echo INFO "[$i]" bootstratp unnecessary for ${SCRAM_ARCH} in crab3
   #exit 0
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

echo DEBUG using $(ls -t $MYTESTAREA/$SCRAM_ARCH/external/apt/*/etc/profile.d/init.sh | head -1)
source $(ls -t $MYTESTAREA/$SCRAM_ARCH/external/apt/*/etc/profile.d/init.sh | head -1)
source $(ls -t $MYTESTAREA/$SCRAM_ARCH/external/curl/*/etc/profile.d/init.sh | head -1) # cvmfs_server

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
echo INFO "[$i]" executing apt-get install cms+crabclient+$RELEASE
apt-get install --assume-yes cms+crabclient+$RELEASE
status=$?
if [ $status -ne 0 ] ; then
   echo ERROR apt-get install cms+crabclient+$RELEASE failed
   echo Exiting from $(basename $0)
   exit 1
fi

i=$(expr $i + 1)
echo INFO "[$i]" succefully executed apt-get install cms+crabclient+$RELEASE

echo INFO checking $SCRAM_ARCH

echo "${SCRAM_ARCH}" | grep -q slc6_amd64_gcc493
if [ $? -eq 0 ] ; then
  gccv=
  pre_or_not=
  i=$(expr $i + 1)
  echo "${RELEASE}" | grep -q -e "pre\|rc"
  [ $? -eq 0 ] && pre_or_not="_pre"
  for sh_type in sh csh ; do
     for thetype in "" _light ; do
       echo "[ $i ]" sh=$sh_type thetype=$thetype
       echo DEBUG removing $MYTESTAREA/crab${gccv}${pre_or_not}${thetype}.${sh_type}
       rm -f $MYTESTAREA/crab${gccv}${pre_or_not}${thetype}.${sh_type}
       ( cd $MYTESTAREA
         if [ "x$thetype" == "x" ] ; then
              ln -s $MYTESTAREA/${SCRAM_ARCH}/cms/crabclient/${RELEASE}/etc/profile.d/init$(echo "${thetype}" | sed 's#_#-#').${sh_type} crab${gccv}${pre_or_not}${thetype}.${sh_type}
         else
              ln -s $MYTESTAREA/${SCRAM_ARCH}/cms/crabclient/${RELEASE}/etc/init$(echo "${thetype}" | sed 's#_#-#').${sh_type} crab${gccv}${pre_or_not}${thetype}.${sh_type}
         fi
       )
       echo INFO "[$i]" Check $MYTESTAREA/crab${gccv}${pre_or_not}${thetype}.${sh_type}
       ls -al $MYTESTAREA/crab${gccv}${pre_or_not}${thetype}.${sh_type}
       echo ; echo
     done
  done

  theconfig_py_files="ExampleConfiguration.py FullConfiguration.py"
  for thepy in $theconfig_py_files ; do
   rm -f $MYTESTAREA/$thepy
   ( cd $MYTESTAREA
     ln -s $MYTESTAREA/${SCRAM_ARCH}/cms/crabclient/${RELEASE}/etc/$thepy $(echo $thepy | sed "s#\.py#${gccv}\.py#g")
   )
   echo INFO softlink created for $(echo $thepy | sed "s#\.py#${gccv}\.py#g")
  done
fi

if [ "x$cvmfs_server_yes" == "xyes" ] ; then
   grep -q "crabclient $RELEASE ${SCRAM_ARCH}" $updated_list
   if [ $? -eq 0 ] ; then
     echo Warning crabclient $RELEASE ${SCRAM_ARCH} is already in the $updated_list
   else
     echo INFO adding crabclient $RELEASE ${SCRAM_ARCH} to $updated_list
     echo crabclient $RELEASE ${SCRAM_ARCH} $(/bin/date +%s) $(/bin/date -u) >> $updated_list
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
      echo INFO now further doing /cvmfs/cms.cern.ch/crab3/"<scram_arch>"/cms/crabclient/"<rel>"/.cvmfscatalog
      for crab3_rel_dir in $thedir/cms/crabclient/* ; do
          [ "x$crab3_rel_dir" == "x$thedir/cms/crabclient/*" ] && break
          [ -d $crab3_rel_dir ] || continue
          ls -al $crab3_rel_dir/.cvmfscatalog 2>/dev/null 1>/dev/null ;
          if [ $? -eq 0 ] ; then
             echo INFO $crab3_rel_dir/.cvmfscatalog exists
          else
             echo INFO creating $crab3_rel_dir/.cvmfscatalog
             touch $crab3_rel_dir/.cvmfscatalog
          fi
      done
   done
   echo INFO publishing cvmfs
   #publish_cmssw_cvmfs
   echo INFO publishing the installation in the cvmfs
   #time cvmfs_server publish 2>&1 | tee $HOME/cvmfs_server+publish+crabclient+install.log
   currdir=$(pwd)
   cd
   time cvmfs_server publish 2>&1 |  tee $HOME/cvmfs_server+publish+crabclient+install.log
   cd $currdir
   status=$?
   if [ $status -eq 0 ] ; then
      printf "$(basename $0) cvmfs_server_publish OK \n$(cat $HOME/cvmfs_server+publish+crabclient+install.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish for crabclient install OK" $notifytowhom
   else
      echo ERROR failed cvmfs_server publish
      printf "$(basename $0) cvmfs_server publish failed\n$(cat $HOME/cvmfs_server+publish+crabclient+install.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      return 1
   fi

   #echo INFO publishing 
fi # if [ "x$cvmfs_server_yes" == "xyes" ] ; then
#fi # if $updated_list exists thus cvmfs server

exit $status
