#!/bin/sh
#
# Bockjoo Kim, U of Florida
# This is executed in various slc machines.
# I will assume it is executed in slc5 first, then slc6, and then slc7 etc etc
# create a file /cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates to indicate new updates
#
# This script also depends on
# cvmfs_check_siteconf_git.sh
# create_host_proxy_download_siteconf.sh
#
# This script is cronized on the 25th minute on the server $cvmfs_host
# and on the 55th minute on the slc6 machine every hour.
#
# 1.1.2: start of SLC6/CVMFS 2.1
# 1.3.2: start of OSX installation
# 1.3.4: stores releases.map to /cvmfs/cms.cern.ch
# 1.3.6: Incorpration of install_comp_python
# 1.3.9: cron_install_cmssw.config is added to control all the config variables
# 1.4.2: tarball bootstrap : bootstrap_arch_tarball function added
# 1.4.3: update install_cmssw function to cope with cvmfs_swissknife issue with
#         cvmfs_swissknife: /lib64/libc.so.6: version `GLIBC_2.14' not found (required by /cvmfs/cms.cern.ch/slc7_amd64_gcc493/external/bootstrap-bundle/1.0/lib/libstdc++.so.6)
# 1.4.4: crab3 gcc493
# 1.4.5: clean up updated_list for crab3
# 1.4.6: # for cvmfs_server
         # source $(ls -t ${SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
# 1.5.0: # use apt_config explicitly
# 1.5.2: ignore error: rpmdb: BDB2034 unable to allocate memory for mutex; resize mutex region
#        as far as apt-get install returns status=0
# 1.5.3: openssl in addition to the curl added
# 1.5.4: DB_CONFIG auto-creation when there is the "resize mutex region" error
# 1.5.5: added cvmfs_install_POWER8.sh ( 10FEB2016 )
# 1.5.6: RPM_CONFIGDIR setting is removed for non-native installation
# 1.5.7: SCRAM_ARCH_COMPILER check is added to get rid of error: bad option 'archcolor' at (null):97
# 1.5.8
# 1.5.9: install_cmssw_power_archs and install_cmssw_aarch64_archs
# 1.6.0:
# 1.6.1: 2>&1 | tee log is changed to > log 2>&1
# 1.6.2: check_and_update_siteconf() is added
# 1.6.3: rsync -arzup --delete
# 1.6.4: switch from git.cern.ch to gitlab.cern.ch on June 1 9:00 CERN Time
# 1.6.5: $HOME/logs directory and put logs in the directory
# 1.6.6: CMS@Home removed
# 1.6.7: Clean up siteconf update email
# 1.6.8: gcc600 and cvmfs_server lstags -> cvmfs_server tag
# 1.6.9: CVMFS_SERVER_DEBUG=3
# 1.7.0: lxcvmfs73 -> lxcvmfs74
# 1.7.1: cms-common for cmspkg
# 1.7.2: use cmspkg instead of apt-get
# 1.7.3: Cleanup OSX stuffs
# 1.7.4: Docker for slc7
# 1.7.5: CRAB3 client installation is sent to the email
# 1.7.6: use config variables in the config
# 1.7.7: Relocate the log directory to $HOME/logs
# 1.7.8: cmspkg -y upgrade added to install_cmssw
# 1.7.9: update cms-common install with cmspkg
# 1.7.9: phedexagents
# 1.8.0: spacemon-client
# 1.8.1: Changed the way the new package is discovered
# 1.8.2: Changed the way the new CMSSW package is discovered
# version 1.8.2
version=1.8.2

# Basic Configs
WORKDIR=/cvmfs/cms.cern.ch
cvmfs_server_yes=yes
workdir=$HOME
export THISDIR=$workdir

# AARCH tarball
#aarch64_tarball_web=http://davidlt.web.cern.ch/davidlt/vault/aarch64
db=$HOME/$(basename $0 | sed "s#\.sh##g").db.txt
[ -d $HOME/logs ] || mkdir -p $HOME/logs
lock=$workdir/$(basename $0 | sed "s#\.sh##g").lock


CMSSW_REPO=cms
# This is a hack to add dev archs and cmssws to be installed
# Add archs whenever a new cmssw is installed by checking extra archs for the cmssw
dev_arch_cmssws=$HOME/$(basename $0 | sed "s#\.sh##g").dev.arch.cmssws.txt
dev_arch_rpm_list=$HOME/$(basename $0 | sed "s#\.sh##g").dev.arch.rpm

# More configs from the file
if [ ! -f $HOME/cron_install_cmssw.config ] ; then
   #printf "$(basename $0) $HOME/cron_install_cmssw.confg not found\n" | mail -s "ERROR cron_install_cmssw.config not found" $notifytowhom
   echo "$(basename $0) $HOME/cron_install_cmssw.confg not found" >> $lock
fi
cvmfs_server_name=$(grep cvmfs_server_name= $HOME/cron_install_cmssw.config | grep -v \# | cut -d= -f2)
rpmdb_local_dir=$(grep rpmdb_local_dir= $HOME/cron_install_cmssw.config | grep -v \# | cut -d= -f2)
notifytowhom=$(grep notifytowhom= $HOME/cron_install_cmssw.config | grep -v \# | cut -d= -f2)
theuser=$(/usr/bin/whoami)
cvmfs_server_name=$(eval echo $cvmfs_server_name)
[ "$(/bin/hostname -f)" == "x$cvmfs_server_name" ] || cvmfs_server_yes=no

# Don't let the rpmdb_local_dir be deleted
for f in $(find $rpmdb_local_dir -type f -name "*" -print) ; do
   echo INFO touch $f for the rpmdb to be alive
   touch $f
done

echo INFO cvmfs_server_name=$cvmfs_server_name
echo INFO rpmdb_local_dir=$rpmdb_local_dir
echo INFO notifytowhom=$notifytowhom

# Make sure this is the same host as the one in the config file
if [ "X$(/bin/hostname -f)" == "X$cvmfs_server_name" ] ; then
   :
else
   printf "$(basename $0) ERROR Exiting for /bin/hostname=$(/bin/hostname -f) and cvmfs_server_name=$cvmfs_server_name are different\nMaybe update $HOME/cron_install_cmssw.config?\n" | mail -s "ERROR hostname mismatch" $notifytowhom
   exit 1
fi

# Maintenance
[ -f /etc/nologin ] && echo "Cron disabled due to nologin" && exit
if [ "X$(date +%Y%m%d)" == "X20160701" ] ; then
 if [ $(date +%d%H) -ge 107 -a $(date +%d%H) -lt 108 ] ; then #
   echo "lxcvmfs73 -> lxcvmfs74"
   printf "$(basename $0) Exiting for the system upgrade\n$(cat $HOME/crontab | sed 's#%#%%#g')\nlxcvmfs73 to lxcvmfs74\nUpdate $HOME/cron_install_cmssw.config" | mail -s "Exiting for upgrade" $notifytowhom
   exit 0
 fi
fi

# Hour and Minute Now
date_H=$(date +%H)
date_M=$(date +%M)

uname -a | grep -q $cvmfs_server_name
if [ $? -eq 0 ] ; then
   cvmfs_server_yes=yes
else
   printf "$(basename $0) uname -a does not contain $cvmfs_server_name\n$(uname -a | sed 's#%#%%#g')\n" | mail -s "ERROR machine name and cvmfs_server_name differs" $notifytowhom
   exit 1
fi

if [ ! -d $rpmdb_local_dir ] ; then
   mkdir -p $rpmdb_local_dir
   if [ $? -ne 0 ] ; then
      printf "$(basename $0) failed to created rpmdb_local_dir $rpmdb_local_dir\n" | mail -s "ERROR failed to create rpmdb_local_dir" $notifytowhom
      exit 1
   fi
fi

slcs_excluded="_ia32_"
archs_excluded="slc5_amd64_gcc434\|slc5_amd64_gcc451\|slc5_amd64_gcc4621|slc5_amd64_gcc462"
cmssws_excluded="CMSSW_4_2_8_SLHCstd_patch1 CMSSW_4_1_3_patch1 CMSSW_4_2_0 CMSSW_4_2_0_pre6 CMSSW_4_2_2_SLHC_pre1 CMSSW_4_2_3_SLHC_pre1 CMSSW_4_2_8_SLHC1_patch1 MSSW_4_2_8_SLHCstd_patch1 CMSSW_4_3_0_pre7 CMSSW_4_4_2_p10JEmalloc CMSSW_5_0_0_g4emtest CMSSW_5_0_0_pre5_root532rc1 CMSSW_4_2_3_onlpatch2 CMSSW_4_2_3_onlpatch4 CMSSW_4_2_7_hinpatch1 CMSSW_4_2_7_onlpatch2 CMSSW_4_2_9_HLT2_onlpatch1 CMSSW_4_4_2_onlpatch1 CMSSW_5_1_0_pre1 CMSSW_5_1_0_pre2 CMSSW_5_2_0_pre2_TS113282 CMSSW_5_2_0_pre3HLT CMSSW_5_3_4_TS125616patch1 CMSSW_5_3_X CMSSW_6_2_X CMSSW_6_2_X_SLHC CMSSW_7_0_X CMSSW_7_1_X CMSSW_7_2_X CMSSW_7_3_X CMSSW_7_4_X CMSSW_7_1_50"

updated_list=/cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates
cvmfs_self_mon=/cvmfs/cms.cern.ch/oo77

#slc_vm_machines="slc6+vocms10"
#ssh_key_file=$HOME/.ssh/id_rsa

#release_tag_xml="https://cmssdt.cern.ch/SDT/cgi-bin/ReleasesXML?anytype=1"
releases_map="https://cmssdt.cern.ch/SDT/releases.map"
releases_map_local=$workdir/releases.map
bootstrap_script=http://cmsrep.cern.ch/cmssw/cms/bootstrap.sh
#rpms_list=http://cmsrep.cern.ch/cmssw/cms/RPMS/

#archs_list=$HOME/archs_list.txt
#excludes_power="fc22_ppc64le_gcc493\|slc"
#excludes_aarch64="slc7_aarch64_gcc493\|slc[0-9]_amd"

#crab_tarball_top="http://cmsdoc.cern.ch/cms/ccs/wm/scripts/Crab"
#export crab3_REPO=comp.pre.bbockelm
#export crab3_REPO=comp
#export crab3_SCRAM_ARCH=slc5_amd64_gcc461
#crab3_RPMS=http://cmsrep.cern.ch/cmssw/${crab3_REPO}/RPMS/${crab3_SCRAM_ARCH}/

# cms-common
#cms_common_version_archs="1115+slc5_amd64_gcc472"
#cms_common_version_archs="1116+slc5_amd64_gcc481"
#cms_common_version_archs="1118+slc6_amd64_gcc481"
#cms_common_version_archs="1119+slc6_amd64_gcc481"
#cms_common_version_archs="1122+slc6_amd64_gcc493"
#cms_common_version_archs="1123+slc6_amd64_gcc530"
cms_common_version_archs="1129+slc6_amd64_gcc530"

which_slc=slc6
uname -a  | grep ^Linux | grep GNU/Linux | grep -q .el5
[ $? -eq 0 ] && which_slc=slc5
uname -a  | grep ^Linux | grep GNU/Linux | grep -q .el6
[ $? -eq 0 ] && which_slc=slc6
uname -a  | grep ^Linux | grep GNU/Linux | grep -q .el7
[ $? -eq 0 ] && which_slc=slc7

#lock=$workdir/$(basename $0 | sed "s#\.sh##g").lock
date_ymdhs=$(date +%Y-%m-%d_%H:%M)

export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
export LANG="C"
#DOCKER_TAG=bockjoo/slc7:test
DOCKER_TAG=cmssw/slc7:current

functions=$workdir/$(basename $0 | sed "s#\.sh##g")-functions # .$(date -u +%s)

perl -n -e 'print if /^####### BEGIN Functions 12345/ .. /^####### ENDIN Functions 12345/' < $0 | grep -v "Functions 12345" > $functions

if [ ! -f $functions ] ; then
   echo ERROR $functions does not exist
   printf "$(basename $0) ERROR failed to create $functions\nfunctions does not exist\n" | mail -s "ERROR failed to create the functions" $notifytowhom
   exit 1
fi

source $functions
#rm -f $functions

:
: Main
:

j=0
# [] Check sanity of the stratum0 and Check if the script is already running
j=$(expr $j + 1)
echo INFO "[$j]" Checking if the stratum0 is sane
REPO_NAME=cms.cern.ch
need_to_fix_mount_issue=0
if [ $(ls /cvmfs/cms.cern.ch | grep ^slc | wc -l) -lt 15 ] ; then
   printf "$(basename $0) cvmfs mount may be strange\nNumber of SCRAM_ARCH is less than 15\n$(ls /cvmfs/cms.cern.ch)\n" | mail -s "$(basename $0) Number of SCRAM_ARCH < 15" $notifytowhom      
   need_to_fix_mount_issue=1
fi

ls -al $updated_list
if [ $? -ne 0 ] ; then
   printf "$(basename $0) cvmfs mount may be strange\nls -al $updated_list\n$(ls -al $updated_list)\n" | mail -s "$(basename $0) $updated_list not visible" $notifytowhom
fi

cvmfs_server list 
cvmfs_server list  | grep stratum0 | grep -q transaction
if [ $? -eq 0 ] ; then
   if [ ! -f $lock ] ; then
      echo INFO $lock does not exist
      need_to_fix_mount_issue=2
      printf "$(basename $0) cvmfs mount issue\n$lock does not exist\ncvmfs_server list\n$(cvmfs_server list)\n" | mail -s "$(basename $0) needs to fix the mount issue" $notifytowhom      
   fi
fi

ps auxwww | grep -q grep | grep "$theuser"
echo INFO need_to_fix_mount_issue=$need_to_fix_mount_issue

j=$(expr $j + 1)
echo INFO "[$j]" Check if the script is already running
if [ -f $lock ] ; then
   echo INFO $lock exists
   lock_time=$(ls -al $lock | awk '{print $(NF-1)}')
   proc_times=$(ps auxwww | grep -v grep | grep "$theuser" | grep "HOME/cron_install_cmssw.log" | grep "HOME/cron_install_cmssw.sh" | awk '{print $(NF-7)}')
   is_this_running="no because $lock_time <> $proc_times\nPlease remove $lock"
   for proc_time in $proc_times ; do
      [ "x$lock_time" == "x$proc_time" ] && { is_this_running="yes" ; break ; } ;
   done
   printf "$(basename $0) Warning lock exists\n$(ls -al $lock)\nContent of lock\n$(cat $lock)\nDate now is \n$(date)\n$(date -u)\n\n\nIs the lock created process running? Ans: $is_this_running\n\n\n$(ps auxwww | grep -v grep | grep $theuser | grep $0)\nRunning processes\n$(ps auxwww | grep -v grep | grep $theuser)\n" | mail -s "$(basename $0) Warning lock exists" $notifytowhom      
   exit 0
else
   printf "$(basename $0) INFO starting $(basename $0)\n" | mail -s "$(basename $0) [ $date_ymdhs ] starting $(basename $0)" $notifytowhom      
fi

echo INFO creating $lock
echo $(date -u) >> $lock
[ -f $db ] || touch $db

# [] Make sure this script run only on SL
j=$(expr $j + 1)
echo INFO "[$j]" Make sure this script run only on SLC5/SL5/EL5/SLC6/SL6/EL6
if [ "x$which_slc" == "x" ] ; then
   printf "$(basename $0) $(hostname -f) does not seem to be an SLC machine\n$(uname -a)\nThis script is supposed to be run only on an SLC/EL machine\n" | mail -s "ERROR $(basename $0) $(hostname -f) does not seem to be an SLC" $notifytowhom      
   rm -f $lock
   exit 1
fi

# [] Get a list of archs on SLC5/EL5/SL5
j=$(expr $j + 1)
echo INFO "[$j]" Get a list of archs on SLC5/EL5

# Download releases.map once
wget --no-check-certificate -q -O $releases_map_local  "${releases_map}"
if [ $? -ne 0 ] ; then
   printf "$(basename $0) $(hostname -f) failed to download ${releases_map}\n" | mail -s "ERROR $(basename $0) $(hostname -f) failed to download releases_map" $notifytowhom
   rm -f $lock
   exit 1
fi

# release.map
archs=$(list_announced_cmssw_archs | grep -v "$slcs_excluded")

# cmspkg-way 
#archs=$(list_announced_cmssw_slc_amd_archs | grep -v "$slcs_excluded")

narchs=$(echo $archs | wc -w)

## [] Download the archs list every 2 hours for collect_power_arch_rpms_page
#status_rpms_list=0
#if [ $(expr $(date +%H) % 2) -eq 0 ] ; then
#   wget --no-check-certificate -q -O $archs_list "$rpms_list"
#   if [ $? -ne 0 ] ; then
#      # Affects auto-installation of aarch and power arch, but non-critical
#      printf "$(basename $0) $(hostname -f) failed to download $rpms_list\n" | mail -s "ERROR $(basename $0) $(hostname -f) failed to download rpms_list" $notifytowhom
#      status_rpms_list=1
#      #rm -f $lock
#      #exit 1
#   fi
#fi

echo INFO archs available
for a in $archs ; do
    echo $a
done

# Check Point 1
#rm -f $lock
#exit 0

i=0
nslc=$(echo $VO_CMS_SW_DIR/slc* | wc -w)
for thedir in $VO_CMS_SW_DIR/slc* ; do
   [ "x$thedir" == "x$VO_CMS_SW_DIR/slc*" ] && break
   [ -d $thedir ] || continue
   i=$(expr $i + 1)
   ls -al $thedir/.cvmfscatalog 2>/dev/null 1>/dev/null ;
   if [ $? -eq 0 ] ; then
      echo INFO "[ $i / $nslc ]" $thedir/.cvmfscatalog exists
   else
      # new in CVMFS 2.1
      printf "$(basename $0) Starting cvmfs_server transaction for cvmfscatalog\n" | mail -s "cvmfs_server transaction started" $notifytowhom
      cvmfs_server transaction
      status=$?
      what="$(basename $0) $thedir/.cvmfscatalog"
      cvmfs_server_transaction_check $status $what
      if [ $? -eq 0 ] ; then
         echo INFO transaction OK for $what
      else
         printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
         rm -f $lock
         exit 1
      fi
      echo INFO "[ $i / $nslc ]" creating $thedir/.cvmfscatalog
      touch $thedir/.cvmfscatalog
 
      currdir=$(pwd)
      cd
      time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish.log
      cd $currdir
      printf "install_crab3 () published  \n$(cat $HOME/logs/cvmfs_server+publish.log | sed 's#%#%%#g')\n" | mail -s "cvmfs_server publish Done" $notifytowhom
   fi
done

# Check Point 2
#rm -f $lock
#exit 0

# [] cms-common
install_cms_common

# Check Point 3
#echo DEBUG done with install_cms_common
#rm -f $lock
#exit 0

# [] install cmssw
i=0
j=$(expr $j + 1)
echo INFO "[$j]" ARCHS Available: $archs
for arch in $archs ; do
  echo "$arch" | grep -q amd64_gcc
  [ $? -eq 0 ] || continue
  echo "$arch" | grep -q slc5_amd64_gcc
  [ $? -eq 0 ] && continue

  i=$(expr $i + 1)
  echo "     INFO [ $i / $narchs ]" arch=$arch
  # Do a bootstrap if necessary
  j=$(expr $j + 1)
  echo INFO "[$j]" do a bootstrap if necessary
  if [ $(ls -al $VO_CMS_SW_DIR/${arch}/external/apt/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null ; echo $? ; ) -eq 0 ] ; then
     echo INFO "[$j]" arch $arch seems to be already bootstrapped
  else
     bootstrap_arch $arch
     if [ $? -eq 0 ] ; then
        printf "$(basename $0) $(hostname -f) Success: bootstrap_arch $arch \n$(cat $VO_CMS_SW_DIR/bootstrap_${arch}.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) $(hostname -f) Success: bootstrap_arch $arch " $notifytowhom      
     else
        echo INFO checking if it is an slc7
        echo $arch | grep -q slc7
        if [ $? -eq 0 ] ; then
           #bootstrap_arch_tarball $arch > $HOME/bootstrap_${arch}.log 2>&1
           bootstrap_arch_slc7 $arch > $workdir/logs/bootstrap_arch_slc7_${arch}.log
           if [ $? -eq 0 ] ; then
              printf "$(basename $0) $(hostname -f) Success: bootstrap_arch_tarball $arch \n$(cat $VO_CMS_SW_DIR/bootstrap_${arch}.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) $(hostname -f) Success: bootstrap_arch_tarball $arch " $notifytowhom
           else
              printf "$(basename $0) $(hostname -f) failed: bootstrap_arch $arch \n" | mail -s "ERROR $(basename $0) $(hostname -f) bootstrap_arch $arch failed " $notifytowhom
              continue
           fi
        else
           printf "$(basename $0) $(hostname -f) unable to bootstrap: bootstrap_arch $arch \n" | mail -s "ERROR $(basename $0) $(hostname -f) unable to bootstrap $arch" $notifytowhom
           continue
        fi
     fi

     # rpmdb needs to be small/local on the cvmfs server, create a softlink that is backed up
     if [ "x$cvmfs_server_yes" == "xyes" ] ; then
        echo INFO rpmdb needs to be small/local on the cvmfs server, create a softlink that is backed up
        ( cd $VO_CMS_SW_DIR/${arch}/var/lib
          if [ -L rpm ] ; then
             echo INFO soft link for rpm exists
             ls -al rpm
          else
             echo Warning creating the needed soft-link
             cp -pR rpm rpm.$(date +%d%b%Y | tr '[a-z]' '[A-Z]')
             cp -pR rpm ${rpmdb_local_dir}/rpm_${arch}
             rm -rf rpm
             ln -s  ${rpmdb_local_dir}/rpm_${arch} rpm
          fi
        )
     fi
  fi
  j=$(expr $j + 1)
  echo INFO "[$j]" install cmssw if necessary for $arch
  # release.map
  cmssws=$(list_announced_arch_cmssws $arch | grep CMSSW_)
  #cmssws=$(list_announced_arch_cmssws_cmspkg_way $arch)
  if [ $? -ne 0 ] ; then
     printf "ERROR: list_announced_arch_cmssws $arch failed\n" | mail -s "ERROR: list_announced_arch_cmssws $arch failed" $notifytowhom
     continue
  fi
  k=0
  ncmssws=$(echo $cmssws | wc -w)
  echo DEBUG WILL DO arch=$arch and
  for cmssw in $cmssws ; do
      echo $cmssw
  done
  for cmssw in $cmssws ; do
     echo $arch | grep -q slc6_amd64_gcc600
     if [ $? -eq 0 ] ; then
        echo $cmssw | grep -q CMSSW_8_1_0_pre[4-8]
        [ $? -eq 0 ] && continue
     fi
     grep -q "$cmssw $arch" $updated_list # if it is not in the updated_list, it should be reinstall, e.g., power outage, $db
     if [ $? -eq 0 ] ; then
        #echo "          INFO [ $k / $ncmssws ]" cmssw=$cmssw arch=$arch in the db $updated_list
        continue
     fi

     for cmssw_e in $cmssws_excluded ; do
         echo "+"${cmssw_e}"+"
     done | grep -q "+"${cmssw}"+"
     if [ $? -eq 0 ] ; then
        echo Warning ${cmssw} is in $cmssws_excluded Skipping it
        continue
     fi

     # 4 install cmssw
     #j=$(expr $j + 1)
     k=$(expr $k + 1)
     echo "INFO [ $k / $ncmssws ]" cmssw=$cmssw arch=$arch
     #echo INFO "[$j]" install cmssw if necessary
     install_cmssw_function=install_cmssw
     #echo "$arch" | grep -q "slc5_\|$which_slc"_
     echo "$arch" | grep -q "slc7_"
     if [ $? -eq 0 ] ; then
        install_cmssw_function=install_cmssw_non_native
        # TODO: use docker installation if docker is available
        #which docker 2>/dev/null 1>/dev/null
        #[ $? -eq 0 ] && install_cmssw_function=docker_install_nn_cmssw
        docker images 2>/dev/null | grep $(echo $DOCKER_TAG | cut -d: -f1) | grep -q $(echo $DOCKER_TAG | cut -d: -f2)
        if [ $? -eq 0 ] ; then
           install_cmssw_function=docker_install_nn_cmssw
           printf "$(basename $0) INFO: using docker_install_nn_cmssw to install $cmssw  $arch\n" | mail -s "$(basename $0) INFO: using docker_install_nn_cmssw" $notifytowhom
           #printf "$(basename $0) INFO: Could have used the docker_install_nn_cmssw to install $cmssw  $arch\n" | mail -s "$(basename $0) INFO: Could have used the docker_install_nn_cmssw" $notifytowhom
        else
           printf "$(basename $0) INFO: it seems docker is installed but $DOCKER_TAG not found\n$(docker images | sed 's#%#%%#g')\n" | mail -s "$(basename $0) INFO: $DOCKER_TAG not found" $notifytowhom
        fi
     else
        echo "$arch" | grep -q ${which_slc}_
        if [ $? -ne 0 ] ; then
           echo ERROR do not know how to install $cmssw $arch
           printf "$(basename $0) ERROR: do not know how to install $cmssw  $arch\n" | mail -s "$(basename $0) ERROR: FAILED do not know how to install $cmssw  $arc" $notifytowhom
           continue
        fi
     fi
     # echo INFO "[$j]" executing $install_cmssw_function $cmssw $arch
     echo INFO "$install_cmssw_function $cmssw $arch > $HOME/logs/${install_cmssw_function}+${cmssw}+${arch}.log"
     $install_cmssw_function $cmssw $arch > $HOME/logs/${install_cmssw_function}+${cmssw}+${arch}.log 2>&1
     status=$?
     #cat $HOME/logs/${install_cmssw_function}+${cmssw}+${arch}.log
     echo INFO status of install_cmssw_function $install_cmssw_function $cmssw $arch $status
     if [ $status -ne 0 ] ; then
        #echo "          INFO [ $k / $ncmssws ]" cmssw=$cmssw cvmfs server publication unnecessary
        continue
     fi

     # 15JUL2013 0.6.4 DO it only on the cvmfs server
     add_nested_entry_to_cvmfsdirtab ${arch}
     [ $? -eq 0 ] || printf "$(basename $0) ERROR: Failed to add the entry /${arch}/cms/$thecmssw to $VO_CMS_SW_DIR/.cvmfsdirtab\n" | mail -s "$(basename $0) ERROR: FAILED to add the nested CVMFS dir entry for $arch" $notifytowhom
     # 15JUL2013 0.6.4

     # 5 publish the install cmssw on cvmfs
     j=$(expr $j + 1)
     echo INFO "[$j]" publish the installed cmssw on cvmfs if necessary
     publish_cmssw_cvmfs ${0}+${cmssw}+${arch}
     if [ $? -eq 0 ] ; then
        echo "INFO [ $k / $ncmssws ]" cmssw=$cmssw arch=$arch published
        grep -q "$cmssw $arch" $db
        [ $? -eq 0 ] || { echo "INFO [ $k / $ncmssws ]" adding cmssw=$cmssw arch=$arch  to $db ; echo "$cmssw $arch" >> $db ; } ;
        grep -q "$cmssw $arch" $updated_list
        if [ $? -ne 0 ] ; then
          currdir_1=$(pwd)
          cd
          cvmfs_server transaction
          status=$?
          what="adding_$cmssw_$arch_to_updated_list"
          cvmfs_server_transaction_check $status $what
          if [ $? -eq 0 ] ; then
             echo INFO transaction OK for $what
          fi
          echo INFO adding $cmssw $arch to $updated_list
          echo $cmssw $arch $(/bin/date +%s) $(/bin/date -u) >> $updated_list
          printf "$(basename $0): $cmssw $arch added to $updated_list \n$(cat $updated_list)\n" | mail -s "$(basename $0): INFO $cmssw $arch added to $updated_list" $notifytowhom
          publish_cmssw_cvmfs ${0}+${cmssw}+${arch}+$updated_list
          cd $currdir_1
        fi
     else
        printf "$(basename $0): cvmfs_server publish failed for $cmssw $arch \n$(cat $HOME/logs/cvmfs_server+publish+cmssw+install.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0): cvmfs_server publish failed" $notifytowhom
     fi
  done
done

# [] install power arch
echo INFO "executing install_cmssw_power_archs 2>&1 | tee  $HOME/logs/install_cmssw_power_archs.log"
install_cmssw_power_archs 2>&1 | tee  $HOME/logs/install_cmssw_power_archs.log

# [] install slc aarch
echo INFO executing "install_cmssw_aarch64_archs 2>&1 | tee $HOME/logs/cvmfs_install_aarch64.log"
install_cmssw_aarch64_archs 2>&1 | tee $HOME/logs/cvmfs_install_aarch64.log

echo
echo INFO Done CMSSW installation part of the script

# Check Point 4
#rm -f $lock
#exit 0

# [] siteconf
echo INFO Next check_and_update_siteconf using gitlab
echo
check_and_update_siteconf > $HOME/logs/check_and_update_siteconf.log 2>&1
echo INFO Done check_and_update_siteconf using gitlab
echo

# [] CRAB3
echo INFO Next CRAB3 EL6 gcc493 update will be checked and updated as needed
echo
echo INFO installing slc6 gcc493 crab3
install_slc6_amd64_gcc493_crab3
echo
echo INFO Done CRAB3 EL6 gcc493 check and update part of the script
echo

# [] PHEDEX
echo INFO Next PhEDEXAgents EL6 gcc493 update will be checked and updated as needed
echo
echo INFO installing slc6 gcc493 phedexagents
install_slc6_amd64_gcc493_phedexagents
echo
echo INFO Done PhEDExAgents EL6 gcc493 check and update part of the script
echo
# [] spacemon-client
echo INFO Next spacemon-client EL6 gcc493 update will be checked and updated as needed
echo
echo INFO installing slc6 gcc493 spacemonclient
install_slc6_amd64_gcc493_spacemonclient
echo
echo INFO Done spacemon-client EL6 gcc493 check and update part of the script
echo

echo INFO Next LHAPDF update will be checked and updated as needed
echo

# [] lhapdf
$HOME/cron_download_lhapdf.sh 2>&1 | tee $HOME/logs/cron_download_lhapdf.log
lha_pdfsets_version=$(grep ^lhapdfweb_updates= $HOME/cron_download_lhapdf.sh | awk '{print $NF}' | cut -d\" -f1)
grep -q "INFO publishing" $HOME/logs/cron_download_lhapdf.log
if [ $? -eq 0 ] ; then
   if [ ! -f $HOME/logs/cron_download_lhapdf.${lha_pdfsets_version}.log ] ; then
      cp $HOME/logs/cron_download_lhapdf.log $HOME/logs/cron_download_lhapdf.${lha_pdfsets_version}.log
   fi
fi
echo
echo INFO Done LHAPDF check and update part of the script

# [] gridpacks
echo INFO Execute only the first half of the even hours
echo INFO Next cron_rsync_generator_package_from_eos as needed
echo
$HOME/cron_rsync_generator_package_from_eos.sh > $HOME/logs/cron_rsync_generator_package_from_eos.log 2>&1
echo
echo INFO Done cron_rsync_generator_package_from_eos part of the script
echo

# [] pilot config
echo INFO Next Pilot config udate will be checked and updated as needed
$HOME/cvmfs_update_pilot_config.sh 2>&1 | tee $HOME/logs/cvmfs_update_pilot_config.log
echo INFO Done Pilot config check and update part of the script

# [] python
echo INFO Next COMP+python update will be checked and updated as needed
install_comp_python
echo INFO Done COMP+python EL6 check and update part of the script

# [] git mirroring
echo INFO Next git mirror update will be checked and updated as needed
echo
# run daily at 01 AM CERN time
THEHOUR=$(date +%H)
RUN_WHEN=20
if [ "x$THEHOUR" == "x$RUN_WHEN" ] ; then
      $HOME/update_cmssw_git_mirror.sh daily > $HOME/logs/update_cmssw_git_mirror.daily.log 2>&1
fi
echo INFO Done git mirror check
# Check Point 5
#rm -f $lock
#exit 0

echo INFO Next update the self-monitoring

cvmfs_server transaction
status=$?
what="$(basename $0) cvmfs_self_mon"
cvmfs_server_transaction_check $status $what
if [ $? -eq 0 ] ; then
   echo INFO transaction OK for $what
else
   printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
   rm -f $lock
   exit 1
fi

# Cleanups
cleanup_downloaded_rpms=
for d in $VO_CMS_SW_DIR/sl*/var/lib/cache/sl* $VO_CMS_SW_DIR/fc*/var/lib/cache/fc* $VO_CMS_SW_DIR/osx*/var/lib/cache/osx* ; do
   for f in $(find $d -name "*.rpm" -print) ; do
       [ -f "$f" ] && cleanup_downloaded_rpms="$cleanup_downloaded_rpms $f"
       echo rm -f $f
       rm -f $f
   done
done
if [ "x$cleanup_downloaded_rpms" != "x" ] ; then
   printf "$(basename $0) INFO there were rpms in the cache\nThey were cleaned up\n$cleanup_downloaded_rpms\n" | mail -s "$(basename $0) RPMS cleaned up" $notifytowhom
fi

UTC_TIME=$(/bin/date -u +%s)_$(/bin/date -u +%Y-%m-%d-%H:%M:%S)
CERN_TIME=$(/bin/date +%s)_$(/bin/date +%Y-%m-%d-%H:%M:%S)
printf "%32s %32s\n"  "UTC_TIME"  "CERN_TIME"  > $cvmfs_self_mon
printf "%32s %32s\n" "$UTC_TIME" "$CERN_TIME" >> $cvmfs_self_mon
currdir=$(pwd)
cd
time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish.log
cd $currdir

echo script $(basename $0) Done
echo

printf "$(basename $0) Removing $lock from $(/bin/hostname -f)\n" | mail -s "$(basename $0) [ $date_ymdhs ] Removing lock" $notifytowhom

rm -f $lock
exit 0


####### BEGIN Functions 12345
# Functions
function deploy_cmspkg () {
  [ $# -lt 3 ] && { echo ERROR deploy_cmspkg path arch repo ; return 1 ; } ;
  swpath=$1 # /cvmfs/cms.cern.ch/crab3
  ARCH=$2 # slc6_amd64_gcc493
  REPO=$3 # comp

  cd /tmp
  echo INFO downloading cmspkg.py
  wget https://raw.githubusercontent.com/cms-sw/cmspkg/production/client/cmspkg.py

  [ $? -eq 0 ] || { echo ERROR wget cmspkg.py failed ; rm -f cmspkg.py ; cd - ; return 1 ; } ;

  
  [ -f $HOME/cron_install_cmssw.lock ] && { echo ERROR cron_install_cmssw.lock exists ; rm -f cmspkg.py ; cd - ; return 1 ; } ;

  [ -f $HOME/cron_install_cmssw.lock ] || { echo INFO creating cron_install_cmssw.lock at /home/cvcms ; touch cron_install_cmssw.lock ; } ;

  cvmfs_server transaction

  python cmspkg.py --architecture $ARCH --path $swpath --repository comp setup
  status=$?
  [ -f $swpath/common/cmspkg ] || { echo ERROR cmspkg is not installed ; rm -f cmspkg.py ; return 1 ; } ;
  rm -f cmspkg.py
  cd
  cvmfs_server publish
  status=$(expr $status + $?)
  rm -f $HOME/cron_install_cmssw.lock
  return $status
}

function dockerrun()
{
  case "$SCRAM_ARCH" in
    slc7_amd64_* )
      ARGS="cd $THISDIR; $@"
      echo INFO checking docker images ARGS="|"$ARGS"|"
      docker images 2>/dev/null | grep $(echo $DOCKER_TAG | cut -d: -f1) | grep -q $(echo $DOCKER_TAG | cut -d: -f2)
      [ $? -eq 0 ] || { echo ERROR docker image $DOCKER_TAG not found ; return 1 ; } ;
      echo INFO running docker run --rm -i -v /tmp:/tmp -v /cvmfs:/cvmfs -v ${workdir}:${workdir} $DOCKER_TAG sh -c "$ARGS"
      #docker run --rm -it -v /tmp:/tmp -v /cvmfs:/cvmfs -v ${workdir}:${workdir} -u $(whoami) $DOCKER_TAG sh -c "$ARGS"
      #docker run --rm -i -v /tmp:/tmp -v /cvmfs:/cvmfs -v ${workdir}:${workdir} -u $(whoami) $DOCKER_TAG sh -c "$ARGS"
      docker run --rm -i -v /tmp:/tmp -v /cvmfs:/cvmfs -v ${workdir}:${workdir} $DOCKER_TAG sh -c "$ARGS"
      status=$?
      echo INFO done running docker run ...
      return $status
      ;;
    * )
      eval $@
      return $?
      ;;
  esac
}

function dockerrun_ib()
{
  case "$SCRAM_ARCH" in
    slc7_amd64_* )
      ARGS="cd $THISDIR; $@"
      docker run --rm -t -e THISDIR=${THISDIR} -e WORKDIR=${WORKDIR} -e SCRAM_ARCH=${SCRAM_ARCH} -e x=${x} -v /tmp:/tmp -v ${WORKDIR}:${WORKDIR} -v ${THISDIR}:${THISDIR} -u $(whoami) cmssw/slc7-installer:latest sh -c "$ARGS"
      ;;
    slc7_aarch64_* )
      ARGS="export THISDIR=${THISDIR}; export WORKDIR=${WORKDIR}; export SCRAM_ARCH=${SCRAM_ARCH}; export x=${x}; cd ${THISDIR}; $@"
      $PROOTDIR/proot -R $PROOTDIR/centos-7.2.1511-aarch64-rootfs -b /tmp:tmp -b /build:/build -b /cvmfs:/cvmfs -w ${THISDIR} -q "$PROOTDIR/qemu-aarch64 -cpu cortex-a57" sh -c "$ARGS"
      ;;
    fc22_ppc64le_* )
      ARGS="export THISDIR=${THISDIR}; export WORKDIR=${WORKDIR}; export SCRAM_ARCH=${SCRAM_ARCH}; export x=${x}; cd ${THISDIR}; $@"
      $PROOTDIR/proot -R $PROOTDIR/fedora-22-ppc64le-rootfs -b /tmp:/tmp -b /build:/build -b /cvmfs:/cvmfs -w ${THISDIR} -q "$PROOTDIR/qemu-ppc64le -cpu POWER8" sh -c "$ARGS"
      ;;
    * )
      eval $@
      ;;
  esac
}

function list_requested_cmssw_archs () { # This function needs a manual edition
    echo slc6_amd64_gcc472
    cat $dev_arch_cmssws 2>/dev/null | grep slc | awk '{print $1}' | sort -u
    return 0
}

function list_requested_arch_cmssws () { # This function needs a manual edition
    echo slc6_amd64_gcc472 CMSSW_5_3_11
    echo slc6_amd64_gcc472 CMSSW_5_3_11_patch1
    echo slc6_amd64_gcc472 CMSSW_5_3_11_patch2
    echo slc6_amd64_gcc472 CMSSW_5_3_11_patch3
    echo slc6_amd64_gcc472 CMSSW_5_3_11_patch5
    cat $dev_arch_cmssws 2>/dev/null | grep slc | grep CMSSW
    # 12/2/2014
    # There are cases when the release manager did not add the release to the tagxml 
    # https://cmssdt.cern.ch/SDT/cgi-bin/ReleasesXML?anytype=1 
#    /usr/bin/wget -q -O- --connect-timeout=360 --read-timeout=360 http://oo.ihepa.ufl.edu:8080/cmssoft/list_requested_arch_cmssws_cvmfs.txt 2>/dev/null
    cat $HOME/list_requested_arch_cmssws_cvmfs.txt 2>/dev/null
    return 0
}

function list_announced_all_cmssw_archs () {
    CMSSW_REPO=cms
    curl http://cmsrep.cern.ch/cgi-bin/repos/$CMSSW_REPO 2>/dev/null | cut -d\> -f2 | cut -d\< -f1 | sort -u | grep -v $archs_excluded

}

function list_announced_cmssw_slc_amd_archs () {
    #CMSSW_REPO=cms
    #curl http://cmsrep.cern.ch/cgi-bin/repos/$CMSSW_REPO 2>/dev/null | grep slc[0-9]_amd64_| cut -d\> -f2 | cut -d\< -f1 | sort -u | grep -v $archs_excluded
    list_announced_all_cmssw_archs | grep slc[0-9]_amd64_ | grep -v $archs_excluded    
}

function list_announced_cmssw_archs () {
    #a_archs=$(wget --no-check-certificate -q -O- "$release_tag_xml" | grep "<architecture" | cut -d\" -f2 | sort -u)
    #a_archs=$(wget --no-check-certificate -q -O- "${releases_map}" |  cut -d\; -f1 | cut -d= -f2 | sort -u | grep slc | grep -v slc3_ | grep -v slc4_ | grep -v slc5_ia32_)
if [ ] ; then
    releases_map_local=$HOME/releases.map
    releases_map="https://cmssdt.cern.ch/SDT/releases.map"
    wget --no-check-certificate -q -O $releases_map_local  "${releases_map}"
fi # if [ ] ; then
    a_archs=$(cat "$releases_map_local" |  cut -d\; -f1 | cut -d= -f2 | sort -u | grep slc | grep -v slc3_ | grep -v slc4_ | grep -v slc5_ia32_)

    r_archs=$(list_requested_cmssw_archs)
 
    for the_arch in $a_archs $r_archs ; do
       for arch_e in $archs_excluded ; do
         echo "+"${arch_e}"+"
       done | grep -q "+"${the_arch}"+"
       [ $? -eq 0 ] && continue
       echo $the_arch
    done | sort -u
    return 0
}

function list_announced_arch_cmssws_cmspkg_way () {
  export CMSSW_REPO=cms # $crab3repos 
  export SCRAM_ARCH=$1
  cvmfs_server transaction 2>&1 | tee $HOME/logs/cvmfs_server+transaction.log
  [ $? -eq 0 ] || { printf "ERROR: function list_announced_arch_cmssws cvmfs_server transaction failed\n$(cat $HOME/logs/cvmfs_server+transaction.log)\n" | mail -s "ERROR: cvmfs_server transaction failed for list_announced_arch_cmssws" $notifytowhom ; ( cd ; cvmfs_server abort -f ; ) ; return 1 ; } ;

  CMSPKG="$VO_CMS_SW_DIR/common/cmspkg -a $SCRAM_ARCH"

  #echo INFO executing $CMSPKG -y upgrade
  $CMSPKG -y upgrade 2>/dev/null 1>/dev/null
  status=$?
  if [ $status -ne 0 ] ; then
     #echo ERROR $CMSPKG -y upgrade upgrade failed
     ( cd ; cvmfs_server abort -f ; ) ;
     return 1
  fi

  $CMSPKG update 2>/dev/null 1>/dev/null
  status=$?
  if [ $status -ne 0 ] ; then
     #echo ERROR $CMSPKG update failed
     ( cd ; cvmfs_server abort -f ; ) ;
     return 1
  fi
  $CMSPKG search cms+cmssw+ | awk '{print $1}' | sed 's#cms+cmssw+##g'
  $CMSPKG search cms+cmssw-patch+ | awk '{print $1}' | sed 's#cms+cmssw-patch+##g'
  ( cd ; cvmfs_server abort -f ; ) ;
  return 0
}

function list_announced_arch_cmssws () {
    ARCH=$1
    #a_cmssws=$(wget --no-check-certificate -q -O- "${release_tag_xml}&architecture=$ARCH" | grep "<project" | grep "Announced" | cut -d\" -f2 | sort -u)
    #a_cmssws=$(wget --no-check-certificate -q -O- "${releases_map}" | grep "$ARCH" | grep label=CMSSW_ | cut -d\; -f2 | cut -d= -f2)
    a_cmssws=$(cat "$releases_map_local" | grep "$ARCH" | grep label=CMSSW_ | cut -d\; -f2 | cut -d= -f2)
    r_cmssws=$(list_requested_arch_cmssws | grep "$ARCH" | awk '{print $NF}')
    for the_cmssw in $a_cmssws $r_cmssws ; do
       echo $the_cmssw
    done | grep -v CMSSW_[0-9]_[0-9]_X$ | sort -u
    return 0
}

function list_osx_cmssws () {
    ARCH=$1
    a_cmssws=$(wget --no-check-certificate -q -O- "$rpms_list/$ARCH" | grep osx[0-9] | grep "cms+cmssw+CMSSW\|cms+cmssw-patch+CMSSW" | sed "s#href=#|#g"  | cut -d\| -f2 | sed "s#osx#|#g" | cut -d\| -f1 | cut -d+ -f3 | sed "s#-[0-9]# #g" | awk '{print $1}' | sort -u)
    for cmssw in $a_cmssws ; do
        for cmssw_excluded in $osx_cmssws_excluded ; do
           echo "+"${cmssw_excluded}"+"
        done | grep -q "+"${cmssw}"+"
        [ $? -eq 0 ] && continue
        echo $cmssw
    done
    return 0
}

function collect_arch_rpms_page () {
    # to be executed only once at each execution of the script to create arch rpms page files
    a_archs=$(wget --no-check-certificate -q -O- "$rpms_list" | grep slc[0-9]_ | grep amd | sed "s#/</a>#|#g" | sed "s#slc#|slc#g" | cut -d\| -f3 | sort -u)
    for a in $a_archs ; do
        echo "$a" | grep -q "$which_slc"
        [ $? -eq 0 ] && continue
        echo INFO downloading rpm list for $a to ${dev_arch_rpm_list}.${a}.txt
        wget --no-check-certificate -q $rpms_list/${a} -O ${dev_arch_rpm_list}.${a}.txt
        echo INFO downloaded rpm list for $a
        #cat ${dev_arch_rpm_list}.${a}.txt
    done
    return 0
}

function install_cmssw_power_archs () {
    if [ $(expr $(date +%H) % 2) -eq 1 ] ; then
       echo INFO install_cmssw_power_archs executed every 2 hours.
       return 0 # wget --no-check-certificate -q -O $archs_list "$rpms_list"
    fi
    status=0   
    # use cmspkg instead of apt-get
    which cmspkg 2>/dev/null 1>/dev/null
    [ $? -eq 0 ] || { export PATH=$PATH:/cvmfs/cms.cern.ch/common ; } ;

    what=fc
    a_archs=$(grep ${what}[0-9][0-9]_ "$releases_map_local" |  cut -d\; -f1 | cut -d= -f2 | sort -u | grep ppc64le)
    #DRY a_archs=$(list_announced_all_cmssw_archs | grep ^${what} | grep ppc64le)
    for a in $a_archs ; do
        cmssw_releases=$(grep $a "$releases_map_local" | grep label=CMSSW_ | cut -d\; -f2 | cut -d= -f2)
        for cmssw_release in $cmssw_releases ; do
            grep -q "$cmssw_release $a " $updated_list
            [ $? -eq 0 ] && { echo INFO $cmssw_release $a installed according to the $updated_list ; continue ; } ;
            echo INFO $cmssw_release $a needs to be installed
            echo INFO executing $HOME/cvmfs_install_POWER8.sh "$a" "$cmssw_release"
            $HOME/cvmfs_install_POWER8.sh "$a" "$cmssw_release" > $HOME/logs/cvmfs_install_POWER8.${a}.${cmssw_release}.log 2>&1
            status=$(expr $status + $?)
            cat $HOME/logs/cvmfs_install_POWER8.${a}.${cmssw_release}.log
        done
    done
    return $status
}

function install_cmssw_power_archs_apt () {
    if [ $(expr $(date +%H) % 2) -eq 1 ] ; then
       echo INFO install_cmssw_power_archs executed every 2 hours.
       return 0 # wget --no-check-certificate -q -O $archs_list "$rpms_list"
    fi
   
    # use cmspkg instead of apt-get
    which cmspkg 2>/dev/null 1>/dev/null
    [ $? -eq 0 ] || { export PATH=$PATH:/cvmfs/cms.cern.ch/common ; } ;

    what=fc
    # required
    # rpms_list=http://cmsrep.cern.ch/cmssw/cms/RPMS/
    # dev_arch_rpm_list=$HOME/$(basename $0 | sed "s#\.sh##g").dev.arch.rpm
    [ "x$rpms_list" == "x" ] && rpms_list=http://cmsrep.cern.ch/cmssw/cms/RPMS/
    [ "x$dev_arch_rpm_list" == "x" ] && dev_arch_rpm_list=$HOME/cron_install_cmssw.dev.arch.rpm
    # to be executed only once at each execution of the script to create arch rpms page files
    #a_archs=$(wget --no-check-certificate -q -O- "$rpms_list" | grep fc[0-9][0-9]_ | grep ppc64le | grep -v "$excludes" | sed "s#/</a>#|#g" | sed "s#fc#|fc#g" | cut -d\| -f3 | sort -u)
    a_archs=$(grep ${what}[0-9][0-9]_ $archs_list | grep ppc64le | grep -v "$excludes_power" | sed "s#/</a>#|#g" | sed "s#${what}#|${what}#g" | cut -d\| -f3 | sort -u)
    for a in $a_archs ; do
        #echo "$a" | grep -q "$which_slc"
        #[ $? -eq 0 ] && continue
        echo INFO downloading rpm list for $a to ${dev_arch_rpm_list}.${a}.txt
        wget --no-check-certificate -q $rpms_list/${a} -O ${dev_arch_rpm_list}.${a}.txt
        echo INFO downloaded rpm list for $a
        #cat ${dev_arch_rpm_list}.${a}.txt
        cmssw_releases=$(grep "cms+cmssw+CMSSW\|cms+cmssw-patch+CMSSW" ${dev_arch_rpm_list}.${a}.txt | sed "s#href=#|#g"  | cut -d\| -f2 | sed "s#${what}#|#g" | cut -d\| -f1 | cut -d+ -f3 | sed "s#-[0-9]# #g" | awk '{print $1}' | sort -u)
        for cmssw_release in $cmssw_releases ; do
            grep -q "$cmssw_release $a " $updated_list
            [ $? -eq 0 ] && { echo INFO $cmssw_release $a installed according to the $updated_list ; continue ; } ;
            echo INFO $cmssw_release $a needs to be installed
            echo INFO executing $HOME/cvmfs_install_POWER8.sh "$a" "$cmssw_release"
            $HOME/cvmfs_install_POWER8_apt.sh "$a" "$cmssw_release" 2>&1 | tee $HOME/POWER8/cvmfs_install_POWER8.${a}.${cmssw_release}.log
        done
    done
    return 0
}


function install_cmssw_aarch64_archs () {
    if [ $(expr $(date +%H) % 2) -eq 1 ] ; then
       echo INFO install_cmssw_aarch64_archs executed every 2 hours.
       return 0 # wget --no-check-certificate -q -O $archs_list "$rpms_list"
    fi
   
    # use cmspkg instead of apt-get
    which cmspkg 2>/dev/null 1>/dev/null
    [ $? -eq 0 ] || { export PATH=$PATH:/cvmfs/cms.cern.ch/common ; } ;

    status=0

    what=slc
    chip=aarch64
    # required
    # rpms_list=http://cmsrep.cern.ch/cmssw/cms/RPMS/
    # dev_arch_rpm_list=$HOME/$(basename $0 | sed "s#\.sh##g").dev.arch.rpm
    #[ "x$rpms_list" == "x" ] && rpms_list=http://cmsrep.cern.ch/cmssw/cms/RPMS/
    #[ "x$dev_arch_rpm_list" == "x" ] && dev_arch_rpm_list=$HOME/cron_install_cmssw.dev.arch.rpm
    # to be executed only once at each execution of the script to create arch rpms page files
    #a_archs=$(wget --no-check-certificate -q -O- "$rpms_list" | grep fc[0-9][0-9]_ | grep ppc64le | grep -v "$excludes" | sed "s#/</a>#|#g" | sed "s#fc#|fc#g" | cut -d\| -f3 | sort -u)
    #a_archs=$(grep ${what}[0-9]_ $archs_list | grep $chip | grep -v "$excludes_aarch64" | sed "s#/</a>#|#g" | sed "s#${what}#|${what}#g" | cut -d\| -f3 | sort -u)
    a_archs=$(grep ${what}[0-9]_ "$releases_map_local" |  cut -d\; -f1 | cut -d= -f2 | sort -u | grep $chip)
    for a in $a_archs ; do
        #echo "$a" | grep -q "$which_slc"
        #[ $? -eq 0 ] && continue
        #echo INFO downloading rpm list for $a to ${dev_arch_rpm_list}.${a}.txt
        #wget --no-check-certificate -q $rpms_list/${a} -O ${dev_arch_rpm_list}.${a}.txt
        #echo INFO downloaded rpm list for $a
        #cat ${dev_arch_rpm_list}.${a}.txt
        #cmssw_releases=$(grep "cms+cmssw+CMSSW\|cms+cmssw-patch+CMSSW" ${dev_arch_rpm_list}.${a}.txt | sed "s#href=#|#g"  | cut -d\| -f2 | sed "s#${what}#|#g" | cut -d\| -f1 | cut -d+ -f3 | sed "s#-[0-9]# #g" | awk '{print $1}' | sort -u)
        cmssw_releases=$(grep $a "$releases_map_local" | grep label=CMSSW_ | cut -d\; -f2 | cut -d= -f2)

        for cmssw_release in $cmssw_releases ; do
            grep -q "$cmssw_release $a " $updated_list
            [ $? -eq 0 ] && { echo INFO $cmssw_release $a installed according to the $updated_list ; continue ; } ;
            echo INFO $cmssw_release $a needs to be installed
            echo INFO executing $HOME/cvmfs_install_aarch64.sh "$a" "$cmssw_release"
            $HOME/cvmfs_install_aarch64.sh "$a" "$cmssw_release" > $HOME/logs/cvmfs_install_aarch64.${a}.${cmssw_release}.log 2>&1
            status=$(expr $status + $?)
            cat $HOME/logs/cvmfs_install_aarch64.${a}.${cmssw_release}.log
        done
    done
    return $status
}

function install_cmssw_aarch64_archs_apt () {
    if [ $(expr $(date +%H) % 2) -eq 1 ] ; then
       echo INFO install_cmssw_aarch64_archs executed every 2 hours.
       return 0 # wget --no-check-certificate -q -O $archs_list "$rpms_list"
    fi
   
    # use cmspkg instead of apt-get
    which cmspkg 2>/dev/null 1>/dev/null
    [ $? -eq 0 ] || { export PATH=$PATH:/cvmfs/cms.cern.ch/common ; } ;

    what=slc
    chip=aarch64
    # required
    # rpms_list=http://cmsrep.cern.ch/cmssw/cms/RPMS/
    # dev_arch_rpm_list=$HOME/$(basename $0 | sed "s#\.sh##g").dev.arch.rpm
    [ "x$rpms_list" == "x" ] && rpms_list=http://cmsrep.cern.ch/cmssw/cms/RPMS/
    [ "x$dev_arch_rpm_list" == "x" ] && dev_arch_rpm_list=$HOME/cron_install_cmssw.dev.arch.rpm
    # to be executed only once at each execution of the script to create arch rpms page files
    #a_archs=$(wget --no-check-certificate -q -O- "$rpms_list" | grep fc[0-9][0-9]_ | grep ppc64le | grep -v "$excludes" | sed "s#/</a>#|#g" | sed "s#fc#|fc#g" | cut -d\| -f3 | sort -u)
    a_archs=$(grep ${what}[0-9]_ $archs_list | grep $chip | grep -v "$excludes_aarch64" | sed "s#/</a>#|#g" | sed "s#${what}#|${what}#g" | cut -d\| -f3 | sort -u)
    for a in $a_archs ; do
        #echo "$a" | grep -q "$which_slc"
        #[ $? -eq 0 ] && continue
        echo INFO downloading rpm list for $a to ${dev_arch_rpm_list}.${a}.txt
        wget --no-check-certificate -q $rpms_list/${a} -O ${dev_arch_rpm_list}.${a}.txt
        echo INFO downloaded rpm list for $a
        #cat ${dev_arch_rpm_list}.${a}.txt
        cmssw_releases=$(grep "cms+cmssw+CMSSW\|cms+cmssw-patch+CMSSW" ${dev_arch_rpm_list}.${a}.txt | sed "s#href=#|#g"  | cut -d\| -f2 | sed "s#${what}#|#g" | cut -d\| -f1 | cut -d+ -f3 | sed "s#-[0-9]# #g" | awk '{print $1}' | sort -u)
        for cmssw_release in $cmssw_releases ; do
            grep -q "$cmssw_release $a " $updated_list
            [ $? -eq 0 ] && { echo INFO $cmssw_release $a installed according to the $updated_list ; continue ; } ;
            echo INFO $cmssw_release $a needs to be installed
            echo INFO executing $HOME/cvmfs_install_aarch64.sh "$a" "$cmssw_release"
            $HOME/cvmfs_install_aarch64_apt.sh "$a" "$cmssw_release" 2>&1 | tee $HOME/logs/cvmfs_install_POWER8.${a}.${cmssw_release}.log
        done
    done
    return 0
}

function collect_osx_rpms_page () {
    a_archs=$(wget --no-check-certificate -q -O- "$rpms_list" | grep osx[0-9] | grep amd | sed "s#/</a>#|#g" | sed "s#osx#|osx#g" | cut -d\| -f3 | sort -u)
    for a in $a_archs ; do
        for arch_osx in $osx_excluded ; do
           echo "+"${arch_osx}"+"
        done | grep -q "+"${a}"+"
        [ $? -eq 0 ] && continue
        echo $a
    done
    return 0
}


function list_cmssw_dev_archs () {
    cmssw=$1
    arch=$2
    # a few checks
    echo "$cmssw" | grep -q CMSSW_
    [ $? -eq 0 ] || return 1
    echo "$arch" | grep -q slc
    [ $? -eq 0 ] || return 1

    echo DEBUG ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1)
    if [ ! -f ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1) ] ; then
      touch ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1)
    fi

    # available archs
    a_archs=$(wget --no-check-certificate -q -O- "$rpms_list" | grep slc[0-9]_ | grep amd | sed "s#/</a>#|#g" | sed "s#slc#|slc#g" | cut -d\| -f3 | sort -u | grep -v "$arch")
    for a in $a_archs ; do
       #1.1.9 grep cms+cmssw ${dev_arch_rpm_list}.${a}.txt | grep +${cmssw}- | grep -q \\.rpm
       grep cms+cmssw ${dev_arch_rpm_list}.${a}.txt | grep "cms+cmssw+${cmssw}-\|cms+cmssw-patch+${cmssw}-" | grep -q \\.rpm

       if [ $? -eq 0 ] ; then
          grep -q "$a $cmssw" ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1)
          [ $? -eq 0 ] && { echo DEBUG ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1) already has it ; continue ; } ;
          echo $a $cmssw
          echo $a $cmssw >> ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1)
          echo DEBUG updated: ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1)
          printf "list_cmssw_dev_archs() adding $a $cmssw to ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1)" | mail -s "list_cmssw_dev_archs $a $cmssw added" $notifytowhom
       fi
    done
    return 0
}

function update_cmssw_dev_archs () {
    cmssw=$1
    arch=$2
    # a few checks
    echo "$cmssw" | grep -q CMSSW_
    [ $? -eq 0 ] || return 1
    echo "$arch" | grep -q slc
    [ $? -eq 0 ] || return 1

    echo DEBUG ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1)
    if [ ! -f ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1) ] ; then
      touch ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1)
    fi

    # available archs
    a_archs=$(wget --no-check-certificate -q -O- "$rpms_list" | grep slc[0-9]_ | grep amd | sed "s#/</a>#|#g" | sed "s#slc#|slc#g" | cut -d\| -f3 | sort -u | grep -v "$arch")
    for a in $a_archs ; do
       [ "x$a" == "x$arch" ] && continue
       #1.1.9 grep cms+cmssw ${dev_arch_rpm_list}.${a}.txt | grep +${cmssw}- | grep -q \\.rpm
       grep cms+cmssw ${dev_arch_rpm_list}.${a}.txt | grep "cms+cmssw+${cmssw}-\|cms+cmssw-patch+${cmssw}-" | grep -q \\.rpm

       if [ $? -eq 0 ] ; then
          grep -q "$a $cmssw" ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1)
          [ $? -eq 0 ] && { echo DEBUG ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1) already has it ; continue ; } ;
          echo $a $cmssw
          echo $a $cmssw >> ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1)
          echo DEBUG updated added $a $cmssw to ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1)
          printf "update_cmssw_dev_archs() $(/bin/hostname -s) adding $a $cmssw to ${dev_arch_cmssws}.$(echo $arch | cut -d_ -f1)" | mail -s "update_cmssw_dev_archs $a $cmssw added" $notifytowhom
       fi
    done
    return 0
}

function mock_up_bootstrap_arch () {
   echo INFO "bootstrap_arch()"
   return 0
}

function bootstrap_arch () {
   
   if [ $# -lt 1 ] ; then
      echo ERROR bootstrap_arch"()" scram_arch
      printf "bootstrap_arch() scram_arch\nNot enough number of argument" | mail -s "bootstrap_arch() failed" $notifytowhom
      return 1
   fi
   SCRAM_ARCH=$1
   echo "$SCRAM_ARCH" | grep -q slc[0-9]
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap_arch"()" SCRAM_ARCH=$SCRAM_ARCH does not start with slc
      printf "bootstrap_arch() SCRAM_ARCH=$SCRAM_ARCH does not start with slc\n" | mail -s "bootstrap_arch() failed" $notifytowhom
      return 1
   fi
   echo "$SCRAM_ARCH" | grep -q $which_slc
   [ $? -eq 0 ] || { echo Warning not suitable for $SCRAM_ARCH bootstrapping on $which_slc ; return 1 ; } ;
   
   # 3.1 Check if bootstrap is needed for $arch
   # Because of cmspkg, check rpm instead of apt
   #ls -al $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null
   ls -al $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/rpm/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null
   if [ $? -eq 0 ] ; then
      echo INFO bootstratp unnecessary ${SCRAM_ARCH}
      return 1
   fi
   
   printf "bootstrap_arch () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
   cvmfs_server transaction
   status=$?
   what="bootstrap_arch ()"
   cvmfs_server_transaction_check $status $what
   if [ $? -eq 0 ] ; then
      echo INFO transaction OK for $what
   else
      printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
      return 1
   fi
   echo INFO bootstratp necessary for ${SCRAM_ARCH}
   # 3.2 Download bootstrap.sh
   wget -q -O $VO_CMS_SW_DIR/bootstrap.sh $bootstrap_script
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap_arch"()" failed: wget -O $VO_CMS_SW_DIR/bootstrap.sh $bootstrap_script
      printf "bootstrap_arch() failed: wget -O $VO_CMS_SW_DIR/bootstrap.sh $bootstrap_script\n" | mail -s "bootstrap_arch() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
      return 1
   fi

   # 3.3 Check integrity of bootstrap.sh
   grep -q ^cleanup_and_exit $VO_CMS_SW_DIR/bootstrap.sh
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap_arch"()" cleanup_and_exit not found in the downloaded $VO_CMS_SW_DIR/bootstrap.sh
      printf "bootstrap_arch() cleanup_and_exit not found in the downloaded $VO_CMS_SW_DIR/bootstrap.sh\n" | mail -s "bootstrap_arch() cleanup_and_exit not found in the downloaded $VO_CMS_SW_DIR/bootstrap" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
   echo INFO executing bootstrap.sh
   sh -x $VO_CMS_SW_DIR/bootstrap.sh -repository cms setup -path $VO_CMS_SW_DIR -a ${SCRAM_ARCH} > $VO_CMS_SW_DIR/bootstrap_${SCRAM_ARCH}.log 2>&1 # | tee $VO_CMS_SW_DIR/bootstrap_${SCRAM_ARCH}.log
   status=$?
   if [ $status -eq 0 ] ; then
      tail -1 $VO_CMS_SW_DIR/bootstrap_${SCRAM_ARCH}.log | grep -q "+ exit 0"
      if [ $? -eq 0 ] ; then
         printf "bootstrap_arch() publishing bootstrap for ${SCRAM_ARCH}\n" | mail -s "bootstrap_arch() publishing bootstrap" $notifytowhom
         publish_cmssw_cvmfs bootstrap_for_${SCRAM_ARCH}
      else
         printf "bootstrap_arch FAILED bootstrap.sh 1 cvmfs_server ending transaction\n" | mail -s "bootstrap_arch FAILED bootstrap.sh 1 cvmfs_server end of transaction" $notifytowhom ; 
         ( cd ; cvmfs_server abort -f ; ) ;
         status=1
      fi
   else
      printf "bootstrap_arch FAILED bootstrap.sh 2 cvmfs_server ending transaction\n" | mail -s "bootstrap_arch FAILED bootstrap.sh 2 cvmfs_server end of transaction" $notifytowhom ; ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
   fi
   return $status

}

function bootstrap_arch_slc7 () {
   
   if [ $# -lt 1 ] ; then
      echo ERROR bootstrap_arch_slc7"()" scram_arch
      printf "bootstrap_arch_slc7() scram_arch\nNot enough number of argument" | mail -s "bootstrap_arch_slc7() failed" $notifytowhom
      return 1
   fi
   SCRAM_ARCH=$1
   echo "$SCRAM_ARCH" | grep -q slc7
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap_arch_slc7"()" SCRAM_ARCH=$SCRAM_ARCH does not start with slc
      printf "bootstrap_arch_slc7() SCRAM_ARCH=$SCRAM_ARCH does not start with slc\n" | mail -s "bootstrap_arch_slc7() failed" $notifytowhom
      return 1
   fi

   #return 0
   #echo "$SCRAM_ARCH" | grep -q $which_slc
   #[ $? -eq 0 ] || { echo Warning not suitable for $SCRAM_ARCH bootstrapping on $which_slc ; return 1 ; } ;
   
   # 3.1 Check if bootstrap is needed for $arch
   #Because of cmspkg
   #ls -al $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null
   ls -al $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/rpm/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null
   if [ $? -eq 0 ] ; then
      echo INFO bootstratp unnecessary ${SCRAM_ARCH}
      return 1
   fi
   if [ "$cvmfs_server_yes" == "yes" ] ; then
    printf "bootstrap_arch_slc7 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
    cvmfs_server transaction
    status=$?
    what="bootstrap_arch_slc7 ()"
    cvmfs_server_transaction_check $status $what
    if [ $? -eq 0 ] ; then
      echo INFO transaction OK for $what
    else
      printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
      return 1
    fi
   fi
   echo INFO bootstratp necessary for ${SCRAM_ARCH}
   # 3.2 Download bootstrap.sh
   wget -q -O $workdir/bootstrap.sh $bootstrap_script
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap_arch_slc7"()" failed: wget -O $workdir/bootstrap.sh $bootstrap_script
      printf "bootstrap_arch_slc7() failed: wget -O $workdir/bootstrap.sh $bootstrap_script\n" | mail -s "bootstrap_arch_slc7() failed" $notifytowhom
      [ "$cvmfs_server_yes" == "yes" ] && ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
      return 1
   fi

   # 3.3 Check integrity of bootstrap.sh
   grep -q ^cleanup_and_exit $workdir/bootstrap.sh
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap_arch_slc7"()" cleanup_and_exit not found in the downloaded $workdir/bootstrap.sh
      printf "bootstrap_arch_slc7() cleanup_and_exit not found in the downloaded $workdir/bootstrap.sh\n" | mail -s "bootstrap_arch_slc7() cleanup_and_exit not found in the downloaded $VO_CMS_SW_DIR/bootstrap" $notifytowhom
      [ "$cvmfs_server_yes" == "yes" ] && ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
   echo INFO executing bootstrap.sh
   status=1
   #which docker 2>/dev/null 1>/dev/null
   docker images 2>/dev/null | grep $(echo $DOCKER_TAG | cut -d: -f1) | grep -q $(echo $DOCKER_TAG | cut -d: -f2)
   if [ $? -eq 0 ] ; then
     dockerrun "sh -ex $workdir/bootstrap.sh -repository cms setup -path $VO_CMS_SW_DIR -a $SCRAM_ARCH -y > $workdir/logs/bootstrap_$SCRAM_ARCH.log 2>&1" || (cat $workdir/logs/bootstrap_${SCRAM_ARCH}.log && exit 1)
     status=$?
   else
     /usr/bin/wget -q -O $workdir/${SCRAM_ARCH}.tar.gz --connect-timeout=360 --read-timeout=360 http://oo.ihepa.ufl.edu:8080/cmssoft/${SCRAM_ARCH}.tar.gz 2>/dev/null
     if [ $? -ne 0 ] ; then
         printf "FAILED: bootstrap_arch_slc7 $SCRAM_ARCH\nfrom http://oo.ihepa.ufl.edu:8080/cmssoft/${SCRAM_ARCH}.tar.gz\n" | mail -s "FAILED: bootstrap_arch_slc7 $SCRAM_ARCH" $notifytowhom
         [ "$cvmfs_server_yes" == "yes" ] && ( cd ; cvmfs_server abort -f ) ;
         return 1
     fi
     cd $VO_CMS_SW_DIR
     tar xzvf $workdir/${SCRAM_ARCH}.tar.gz > $workdir/logs/bootstrap_${SCRAM_ARCH}.log 2>&1
     status=$?
   fi
   if [ $status -eq 0 ] ; then
      tail -1 $workdir/logs/bootstrap_${SCRAM_ARCH}.log | grep -q "+ exit 0"
      if [ $? -eq 0 ] ; then
         printf "bootstrap_arch_slc7() publishing bootstrap for ${SCRAM_ARCH}\n" | mail -s "bootstrap_arch_slc7() publishing bootstrap" $notifytowhom
         [ "$cvmfs_server_yes" == "yes" ] && publish_cmssw_cvmfs bootstrap_for_${SCRAM_ARCH}
      else
         printf "bootstrap_arch_slc7 FAILED bootstrap.sh 1 cvmfs_server ending transaction\n" | mail -s "bootstrap_arch_slc7 FAILED bootstrap.sh 1 cvmfs_server end of transaction" $notifytowhom ; 
         [ "$cvmfs_server_yes" == "yes" ] && ( cd ; cvmfs_server abort -f ; ) ;
         status=1
      fi
   else
      printf "bootstrap_arch_slc7 FAILED bootstrap.sh 2 cvmfs_server ending transaction\n" | mail -s "bootstrap_arch_slc7 FAILED bootstrap.sh 2 cvmfs_server end of transaction" $notifytowhom
      [ "$cvmfs_server_yes" == "yes" ] && ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
   fi
   return $status

}

function bootstrap_arch_slc7_old () { # not used any more
   
   if [ $# -lt 1 ] ; then
      echo ERROR bootstrap_arch_slc7"()" scram_arch
      printf "bootstrap_arch_slc7() scram_arch\nNot enough number of argument" | mail -s "bootstrap_arch_slc7() failed" $notifytowhom
      return 1
   fi
   SCRAM_ARCH=$1
   echo "$SCRAM_ARCH" | grep -q slc7
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap_arch_slc7"()" SCRAM_ARCH=$SCRAM_ARCH does not start with slc
      printf "bootstrap_arch_slc7() SCRAM_ARCH=$SCRAM_ARCH does not start with slc\n" | mail -s "bootstrap_arch_slc7() failed" $notifytowhom
      return 1
   fi

   #return 0
   #echo "$SCRAM_ARCH" | grep -q $which_slc
   #[ $? -eq 0 ] || { echo Warning not suitable for $SCRAM_ARCH bootstrapping on $which_slc ; return 1 ; } ;
   
   # 3.1 Check if bootstrap is needed for $arch
   ls -al $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null
   if [ $? -eq 0 ] ; then
      echo INFO bootstratp unnecessary ${SCRAM_ARCH}
      return 1
   fi
   
   printf "bootstrap_arch_slc7 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
   cvmfs_server transaction
   status=$?
   what="bootstrap_arch ()"
   cvmfs_server_transaction_check $status $what
   if [ $? -eq 0 ] ; then
      echo INFO transaction OK for $what
   else
      printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
      return 1
   fi
   echo INFO bootstratp necessary for ${SCRAM_ARCH}
   # 3.2 Download bootstrap.sh
   wget -q -O $workdir/bootstrap.sh $bootstrap_script
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap_arch_slc7"()" failed: wget -O $workdir/bootstrap.sh $bootstrap_script
      printf "bootstrap_arch_slc7() failed: wget -O $workdir/bootstrap.sh $bootstrap_script\n" | mail -s "bootstrap_arch_slc7() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
      return 1
   fi

   # 3.3 Check integrity of bootstrap.sh
   grep -q ^cleanup_and_exit $workdir/bootstrap.sh
   if [ $? -ne 0 ] ; then
      echo ERROR bootstrap_arch_slc7"()" cleanup_and_exit not found in the downloaded $VO_CMS_SW_DIR/bootstrap.sh
      printf "bootstrap_arch_slc7() cleanup_and_exit not found in the downloaded $VO_CMS_SW_DIR/bootstrap.sh\n" | mail -s "bootstrap_arch_slc7() cleanup_and_exit not found in the downloaded $VO_CMS_SW_DIR/bootstrap" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
   echo INFO executing bootstrap.sh
   status=1
   which docker 2>/dev/null 1>/dev/null
   #if [ $? -eq 0 ] ; then
   if [ ] ; then
     #sh -x $VO_CMS_SW_DIR/bootstrap.sh -repository cms setup -path $VO_CMS_SW_DIR -a ${SCRAM_ARCH} > $VO_CMS_SW_DIR/bootstrap_${SCRAM_ARCH}.log 2>&1 # | tee $VO_CMS_SW_DIR/bootstrap_${SCRAM_ARCH}.log
     dockerrun "sh -ex $workdir/bootstrap.sh -repository cms setup -path $VO_CMS_SW_DIR -a $SCRAM_ARCH -y >& $workdir/logs/bootstrap_${SCRAM_ARCH}.log" || (cat $workdir/logs/bootstrap_${SCRAM_ARCH}.log && exit 1)
     status=$?
   else
     /usr/bin/wget -q -O $workdir/${SCRAM_ARCH}.tar.gz --connect-timeout=360 --read-timeout=360 http://oo.ihepa.ufl.edu:8080/cmssoft/${SCRAM_ARCH}.tar.gz 2>/dev/null
     if [ $? -ne 0 ] ; then
         printf "FAILED: bootstrap_arch_slc7 $SCRAM_ARCH\nfrom http://oo.ihepa.ufl.edu:8080/cmssoft/${SCRAM_ARCH}.tar.gz\n" | mail -s "FAILED: bootstrap_arch_slc7 $SCRAM_ARCH" $notifytowhom
         cd ; cvmfs_server abort -f
         return 1
     fi
     cd $VO_CMS_SW_DIR
     tar xzvf $workdir/${SCRAM_ARCH}.tar.gz > $workdir/logs/bootstrap_${SCRAM_ARCH}.log 2>&1
     status=$?
   fi
   if [ $status -eq 0 ] ; then
      tail -1 $workdir/logs/bootstrap_${SCRAM_ARCH}.log | grep -q "+ exit 0"
      if [ $? -eq 0 ] ; then
         printf "bootstrap_arch_slc7() publishing bootstrap for ${SCRAM_ARCH}\n" | mail -s "bootstrap_arch_slc7() publishing bootstrap" $notifytowhom
         publish_cmssw_cvmfs bootstrap_for_${SCRAM_ARCH}
      else
         printf "bootstrap_arch_slc7 FAILED bootstrap.sh 1 cvmfs_server ending transaction\n" | mail -s "bootstrap_arch_slc7 FAILED bootstrap.sh 1 cvmfs_server end of transaction" $notifytowhom ; 
         ( cd ; cvmfs_server abort -f ; ) ;
         status=1
      fi
   else
      printf "bootstrap_arch_slc7 FAILED bootstrap.sh 2 cvmfs_server ending transaction\n" | mail -s "bootstrap_arch_slc7 FAILED bootstrap.sh 2 cvmfs_server end of transaction" $notifytowhom ; ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
   fi
   return $status

}

function mock_up_install_cmssw () {
   echo INFO "install_cmssw()"
   return 0
}

function install_cmssw () {

   # 4.0 Check number of arguments
   if [ $# -lt 2 ] ; then
      echo ERROR install_cmssw"()" cmssw scram_arch
      printf "install_cmssw() cmssw scram_arch\nNot enough number of arguments" | mail -s "install_cmssw() failed" $notifytowhom
      return 1
   fi
   
   # use cmspkg instead of apt-get
   which cmspkg 2>/dev/null 1>/dev/null
   [ $? -eq 0 ] || { export PATH=$PATH:/cvmfs/cms.cern.ch/common ; } ;
   printf "install_cmssw() cmssw_release=$1 arch=$2 using cmspkg\nCheck which cmspkg\n$(which cmspkg)\n" | mail -s "DEBUG install_cmssw() for cmspkg" $notifytowhom

   # 4.1 Check the first argument
   cmssw_release=$1
   export SCRAM_ARCH=$2
   echo "$cmssw_release" | grep -q CMSSW_
   if [ $? -ne 0 ] ; then
      echo ERROR install_cmssw"()" cmssw_release=$cmssw_release does not start with CMSSW_
      printf "install_cmssw() cmssw_release=$cmssw_release does not start with CMSSW_\n" | mail -s "install_cmssw() failed" $notifytowhom
      return 1
   fi
   
   # 4.2 Check the second argument
   echo "$SCRAM_ARCH" | grep -q slc[0-9]
   if [ $? -ne 0 ] ; then
      echo ERROR install_cmssw"()" SCRAM_ARCH=$SCRAM_ARCH does not start with slc
      printf "install_cmssw() SCRAM_ARCH=$SCRAM_ARCH does not start with slc\n" | mail -s "install_cmssw() failed" $notifytowhom
      return 1
   fi

   # 4.3 Check if this is already installed$updated_list
   thedir=cmssw
   echo $cmssw_release | grep -q patch && thedir=cmssw-patch
   echo INFO checking ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src
   ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src 2>/dev/null 1>/dev/null
   if [ $? -eq 0 ] ; then
      status=1
      echo INFO $cmssw_release $SCRAM_ARCH is already installed
      if [ -f "$db" ] ; then
         grep -q "$cmssw_release ${SCRAM_ARCH}" $db
         if [ $? -ne 0 ] ; then
           #echo INFO adding "$cmssw_release ${SCRAM_ARCH}" to $db
           echo "$cmssw_release ${SCRAM_ARCH} $(date +%s) $(date)" >> $db
           #status=0
         fi
      fi
      if [ -f "$updated_list" ] ; then
         grep -q "$cmssw_release ${SCRAM_ARCH}" $updated_list
         if [ $? -ne 0 ] ; then
           #echo INFO adding "$cmssw_release ${SCRAM_ARCH}" to $db
           cvmfs_server transaction
           echo "$cmssw_release ${SCRAM_ARCH} $(date +%s) $(date)" >> $updated_list
           cvmfs_server publish
           #status=0
         fi
      fi
      echo DEBUG "$cmssw_release ${SCRAM_ARCH} status=$status" inside install_cmssw"()"
      return $status
   fi

   # 4.4 prepare and install it
   second_plus=
   cmssw_release_last_string=$(echo $cmssw_release | sed "s#_# #g" | awk '{print $NF}')

   echo "$cmssw_release_last_string" | grep -q patch && second_plus=-patch

   cd $VO_CMS_SW_DIR

   # Because of cmspkg, we should not need this
if [ ] ; then
   apt_config=$(ls -t $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/apt.conf | head -1)

   if [ -f "$(ls -t ${SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)" ] ; then
      source $(ls -t ${SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)
      # for cvmfs_server
      #source $(ls -t ${SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
   else
      echo ERROR failed apt init.sh does not exist: ${SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh
      printf "install_cmssw() apt init.sh does not exist: ${SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh\n" | mail -s "$(basename $0) failed" $notifytowhom
      return 1
   fi
fi # if [ ] ; then

   if [ -f "$(ls -t ${SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)" ] ; then
      # for cvmfs_server
      source $(ls -t ${SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
      echo INFO checking ldd $(which curl)
      ldd $(which curl)
      #echo INFO ldd $(which curl) status=$?
      ldd $(which curl) 2>&1 | grep OPENSSL | grep -q "not found"
      if [ $? -eq 0 ] ; then
         source $(ls -t ${SCRAM_ARCH}/external/openssl/*/etc/profile.d/init.sh | head -1)
      fi
      
      ldd $(which curl) 2>&1 | grep -q "not found"
      if [ $? -eq 0 ] ; then
         echo ERROR failed to set up curl env\nSome library may be missing $(ldd $(which curl))
         printf "install_cmssw()  set up curl env failed\nSome library may be missing\necho ldd $(which curl) result follows\n$(ldd $(which curl))\n" | mail -s "ERROR install_cmssw() set up curl env failed" $notifytowhom
         return 1
      fi
   else
      echo Warning curl init.sh does not exist: ${SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh
      ldd $(which curl)
      echo INFO ldd $(which curl) status=$?
      #printf "install_cmssw() curl init.sh does not exist: ${SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh\n" | mail -s "$(basename $0) failed" $notifytowhom
      #return 1
   fi

   printf "install_cmssw() Starting cvmfs_server transaction for $cmssw_release ${SCRAM_ARCH}\n" | mail -s "cvmfs_server transaction started" $notifytowhom
   cvmfs_server transaction
   status=$?
   what="install_cmssw()_${cmssw_release}_${SCRAM_ARCH}"
   cvmfs_server_transaction_check $status $what
   if [ $? -eq 0 ] ; then
      echo INFO transaction OK for $what
   else
      printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom
      return 1
   fi

   # 17SEP2014
   # 08FEB2016 updated
   if [ "x$cvmfs_server_yes" == "xyes" ] ; then
        echo INFO rpmdb needs to be small/local on the cvmfs server, create a softlink that is backed up
   fi
   cmspkg -a ${SCRAM_ARCH} -y upgrade
   echo DEBUG which rpm
   which rpm
   rpm -qa --queryformat '%{NAME} %{RELEASE}' > $HOME/logs/rpm_qa_NAME_RELEASE.${SCRAM_ARCH}.log 2>&1
   grep -i "^error: " $HOME/logs/rpm_qa_NAME_RELEASE.${SCRAM_ARCH}.log | grep "unable to allocate memory for mutex" | grep -q "resize mutex region"
   if [ $? -eq 0 ] ; then
      grep -q "mutex_set_max 10000000" /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
      if [ $? -ne 0 ] ; then
         echo INFO adding mutex_set_max 1000000 to /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
         echo mutex_set_max 10000000 >> /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
         echo INFO rebuilding the DB
         rpmdb --define "_rpmlock_path /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/lock" --rebuilddb --dbpath /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm 2>&1 | tee $HOME/logs/rpmdb_rebuild.${SCRAM_ARCH}.log
      fi
   fi    
   #echo INFO executing apt-get --assume-yes -c=$apt_config update for $cmssw_release ${SCRAM_ARCH}
   #apt-get --assume-yes -c=$apt_config update > $HOME/apt_get_update.log 2>&1
   echo INFO executing cmspkg -a ${SCRAM_ARCH} update for $cmssw_release ${SCRAM_ARCH}
   cmspkg -a ${SCRAM_ARCH} update > $HOME/logs/cmspkg_update_${SCRAM_ARCH}.log 2>&1
   status=$?

   #grep -i "^error: " $HOME/apt_get_update.log | grep "unable to allocate memory for mutex" | grep -q "resize mutex region"
   grep -i "^error: " $HOME/logs/cmspkg_update_${SCRAM_ARCH}.log | grep "unable to allocate memory for mutex" | grep -q "resize mutex region"
   if [ $? -eq 0 ] ; then
      if [ ! -f /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG ] ; then
         #echo mutex_set_max 1000000 >> /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
         echo mutex_set_max 10000000 >> /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
         #apt-get --assume-yes -c=$apt_config update > $HOME/apt_get_update.log 2>&1
         echo INFO executing cmspkg -a ${SCRAM_ARCH} update for $cmssw_release ${SCRAM_ARCH} again afterupdating /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
         cmspkg -a ${SCRAM_ARCH} update > $HOME/logs/cmspkg_update_${SCRAM_ARCH}.log 2>&1
         status=$?
         #echo DEBUG "apt-get --assume-yes -c=$apt_config update > $HOME/apt_get_update.log 2>&1"
         printf "install_cmssw() /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG had to be added \nContent of $HOME/logs/cmspkg_update_${SCRAM_ARCH}.log\n$(cat $HOME/logs/cmspkg_update_${SCRAM_ARCH}.log | sed 's#%#%%#g')\nstatus=$status\n" | mail -s "install_cmssw() DB_CONFIG added" $notifytowhom
      fi
   fi

   if [ $status -ne 0 ] ; then
      echo ERROR failed cmspkg -a ${SCRAM_ARCH} update
      printf "install_cmssw() cmspkg -a ${SCRAM_ARCH} update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/logs/cmspkg_update_${SCRAM_ARCH}.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw() cmspkg update failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
      return 1
   fi

   echo INFO installing $cmssw_release ${SCRAM_ARCH} via cmspkg -a ${SCRAM_ARCH} -y install cms+cmssw${second_plus}+$cmssw_release
   #apt-get --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$cmssw_release > $HOME/apt_get_install.log 2>&1
   cmspkg -a ${SCRAM_ARCH} -y install cms+cmssw${second_plus}+$cmssw_release > $HOME/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log 2>&1 
   status=$?
   grep -i "^error: " $HOME/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log | grep "unable to allocate memory for mutex" | grep -q "resize mutex region"
   if [ $? -eq 0 ] ; then
      if [ ! -f /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG ] ; then
         echo mutex_set_max 10000000 >> /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
         cmspkg -a ${SCRAM_ARCH} update > $HOME/logs/cmspkg_update_${SCRAM_ARCH}.2.log 2>&1
         status=$?
         cmspkg -a ${SCRAM_ARCH} -y install cms+cmssw${second_plus}+$cmssw_release > $HOME/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.2.log 2>&1
         status=$(expr $status + $?)
         printf "install_cmssw() /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG had to be added for cmspkg -a ${SCRAM_ARCH} -y install cms+cmssw${second_plus}+$cmssw_release\nstatus=$status\nContent of update log\n$(cat $HOME/logs/cmspkg_update_${SCRAM_ARCH}.2.log | sed 's#%#%%#g')\nContent of install log\n$(cat $HOME/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.2.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw() DB_CONFIG added" $notifytowhom
      fi
   fi

   if [ $status -ne 0 ] ; then
      echo ERROR installation failed: $cmssw_release $SCRAM_ARCH
      printf "install_cmssw() installation failed for $cmssw_release $SCRAM_ARCH\nCheck ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src\n$(ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src)\n$(cat $HOME/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log $HOME/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.2.log 2>/dev/null | sed 's#%#%%#g')\n" | mail -s "install_cmssw() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      echo INFO install_cmssw"()" returns here 4
      return 1
   fi
   
   cat $HOME/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log 2>/dev/null
   cat $HOME/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.2.log 2>/dev/null

   ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src 2>/dev/null 1>/dev/null
   if [ $? -ne 0 ] ; then
      echo ERROR strangely $cmssw_release $SCRAM_ARCH is not installed
      printf "install_cmssw() apt-get install failed for $cmssw_release $SCRAM_ARCH\nCheck ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src\n$(ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src)\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      echo INFO install_cmssw"()" returns here 5
      return 1
   fi

   # 1.3.4 update /cvmfs/cms.cern.ch/releases.map
   cp $releases_map_local /cvmfs/cms.cern.ch/
   echo INFO cmssw installed: $cmssw_release $SCRAM_ARCH
   return 0
}

function docker_install_nn_cmssw () {
   
   # 4.0 Check number of arguments
   if [ $# -lt 2 ] ; then
      echo ERROR docker_install_nn_cmssw"()" cmssw scram_arch
      printf "docker_install_nn_cmssw() cmssw scram_arch\nNot enough number of arguments" | mail -s "docker_install_nn_cmssw() failed" $notifytowhom
      return 1
   fi
   
   # use cmspkg instead of apt-get
   which cmspkg 2>/dev/null 1>/dev/null
   [ $? -eq 0 ] || { export PATH=$PATH:/cvmfs/cms.cern.ch/common ; } ;

   # 4.1 Check the first argument
   cmssw_release=$1
   export SCRAM_ARCH=$2
   echo "$cmssw_release" | grep -q CMSSW_
   if [ $? -ne 0 ] ; then
      echo ERROR docker_install_nn_cmssw"()" cmssw_release=$cmssw_release does not start with CMSSW_
      printf "docker_install_nn_cmssw() cmssw_release=$cmssw_release does not start with CMSSW_\n" | mail -s "docker_install_nn_cmssw() failed" $notifytowhom
      return 1
   fi
   
   # 4.2 Check the second argument
   echo "$SCRAM_ARCH" | grep -q slc[0-9]
   if [ $? -ne 0 ] ; then
      echo ERROR docker_install_nn_cmssw"()" SCRAM_ARCH=$SCRAM_ARCH does not start with slc
      printf "docker_install_nn_cmssw() SCRAM_ARCH=$SCRAM_ARCH does not start with slc\n" | mail -s "docker_install_nn_cmssw() failed" $notifytowhom
      return 1
   fi

   # 4.3 Check if this is already installed
   thedir=cmssw
   echo $cmssw_release | grep -q patch && thedir=cmssw-patch
   echo INFO checking ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src
   ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src 2>/dev/null 1>/dev/null
   if [ $? -eq 0 ] ; then
   if [ "$cvmfs_server_yes" == "yes" ] ; then
      status=1
      echo INFO $cmssw_release $SCRAM_ARCH is already installed
      if [ -f "$db" ] ; then
         grep -q "$cmssw_release ${SCRAM_ARCH}" $db
         if [ $? -ne 0 ] ; then
           echo "$cmssw_release ${SCRAM_ARCH} $(date +%s) $(date)" >> $db
           #status=0
         fi
      fi
      if [ -f "$updated_list" ] ; then
         grep -q "$cmssw_release ${SCRAM_ARCH}" $updated_list
         if [ $? -ne 0 ] ; then
           cvmfs_server transaction
           echo "$cmssw_release ${SCRAM_ARCH} $(date +%s) $(date)" >> $updated_list
           cvmfs_server publish
           status=0
         fi
      fi
      return $status
   fi # cvmfs_server_yes
   fi # if [ $? -eq 0 ] ; then

   # 4.4 prepare and install it
   second_plus=
   cmssw_release_last_string=$(echo $cmssw_release | sed "s#_# #g" | awk '{print $NF}')

   echo "$cmssw_release_last_string" | grep -q patch && second_plus=-patch

   echo INFO Check Point docker_install_nn_cmssw
   if [ "$cvmfs_server_yes" == "yes" ] ; then
   printf "docker_install_nn_cmssw() Starting cvmfs_server transaction for $cmssw_release ${SCRAM_ARCH}\n" | mail -s "cvmfs_server transaction started" $notifytowhom
   cvmfs_server transaction
   status=$?
   if [ $status -eq 0 ] ; then
      echo INFO transaction OK
   else
      printf "docker_install_nn_cmssw() cvmfs_server_transaction failed for $cmssw_release ${SCRAM_ARCH}\n" | mail -s "docker_install_nn_cmssw() ERROR: cvmfs_server_transaction failed" $notifytowhom
      return 1
   fi
   fi # if [ "$cvmfs_server_yes" == "yes" ] ; then
   CMSPKG="$VO_CMS_SW_DIR/common/cmspkg -a $SCRAM_ARCH"
   echo INFO executing $CMSPKG -y upgrade
   $CMSPKG -y upgrade
   echo INFO executing cmspkg -a ${SCRAM_ARCH} update and install cms-common for $cmssw_release ${SCRAM_ARCH}
   #dockerrun "${CMSPKG} update > $workdir/logs/cmspkg_update_${SCRAM_ARCH}.log 2>&1 ; status=\$? ; ${CMSPKG} -f install cms+cms-common+1.0 > $workdir/logs/cmspkg_install_cms-common_${SCRAM_ARCH}+$cmssw_release.log 2>&1 ; exit \`expr $? + \$status\`" > $HOME/logs/dockerrun.log 2>&1
   dockerrun "${CMSPKG} update ; status=\$? ; ${CMSPKG} -f install cms+cms-common+1.0 ; exit \`expr $? + \$status\`" > $HOME/logs/dockerrun_install_cms_commong.log 2>&1
   status=$?
   echo INFO content of $HOME/logs/dockerrun_install_cms_commong.log
   cat $HOME/logs/dockerrun_install_cms_commong.log
   cp $HOME/logs/dockerrun_install_cms_commong.log $workdir/logs/cmspkg_update_${SCRAM_ARCH}.log
   cp $HOME/logs/dockerrun_install_cms_commong.log $workdir/logs/cmspkg_install_cms-common_${SCRAM_ARCH}+$cmssw_release.log
   if [ $status -ne 0 ] ; then
      printf "docker_install_nn_cmssw() cmspkg -a ${SCRAM_ARCH} update or install cms-common failed\nContent of $workdir/logs/cmspkg_update_${SCRAM_ARCH}.log\n$(cat $HOME/logs/cmspkg_update_${SCRAM_ARCH}.log | sed 's#%#%%#g')\nContent of $workdir/logs/cmspkg_install_cms-common_${SCRAM_ARCH}+$cmssw_release.log\n$(cat $workdir/logs/cmspkg_install_cms-common_${SCRAM_ARCH}+$cmssw_release.log | sed 's#%#%%#g')\n" | mail -s "docker_install_nn_cmssw() ERROR cmspkg update or install cms-common failed" $notifytowhom
      [ "$cvmfs_server_yes" == "yes" ] && ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
   echo INFO installing $cmssw_release ${SCRAM_ARCH} via dockerrun cmspkg -a ${SCRAM_ARCH} -y install cms+cmssw${second_plus}+$cmssw_release
   dockerrun "${CMSPKG} install -y cms+cmssw${second_plus}+$cmssw_release ; exit \$?" > $HOME/logs/dockerrun.install.log 2>&1
   status=$?
   echo INFO content of $HOME/logs/dockerrun.install.log
   cat $HOME/logs/dockerrun.install.log
   cp $HOME/logs/dockerrun.install.log $workdir/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log
   if [ $status -eq 0 ] ; then
      echo "INFO docker_install_nn_cmssw() cmspkg -a ${SCRAM_ARCH} install -y cms+cmssw${second_plus}+$cmssw_release succeeded"
      printf "docker_install_nn_cmssw() cmspkg -a ${SCRAM_ARCH} install -y cms+cmssw${second_plus}+$cmssw_release succeeded\nContent of $workdir/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log\n$(cat $workdir/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log | sed 's#%#%%#g')\n" | mail -s "docker_install_nn_cmssw() INFO $cmssw_release ${SCRAM_ARCH} installed" $notifytowhom
   else
      mutex_error=
      grep "unable to allocate memory for mutex" $workdir/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log  | grep -q "resize mutex region"
      if [ $? -eq 0 ] ; then
         echo "Required: echo mutex_set_max 10000000 >> /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG"
         #mutex_error="Required: echo mutex_set_max 10000000 >> /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG"
         echo mutex_set_max 10000000 >> /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
         rpm_init_env=$(ls -t /cvmfs/cms.cern.ch/${SCRAM_ARCH}/external/rpm/*/etc/profile.d/init.sh | head -1)
         echo INFO rebuilding the DB
         dockerrun "source $rpm_init_env ; rpmdb --define \"_rpmlock_path /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/lock\" '--rebuilddb' '--dbpath' /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm ; exit \$?" > $HOME/logs/dockerrun_rpmdb_rebuild.${SCRAM_ARCH}.log 2>&1
         if [ $? -eq 0 ] ; then
            dockerrun "${CMSPKG} install -y cms+cmssw${second_plus}+$cmssw_release ; exit \$?" > $HOME/logs/dockerrun.install.log 2>&1
            status=$?
            echo INFO content of $HOME/logs/dockerrun.install.log
            cat $HOME/logs/dockerrun.install.log
            cp $HOME/logs/dockerrun.install.log $workdir/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log
         else
            printf "docker_install_nn_cmssw() rpmdb rebuild failed for ${SCRAM_ARCH} $cmssw_release \n$(cat $HOME/logs/dockerrun_rpmdb_rebuild.${SCRAM_ARCH}.log | sed 's#%#%%#g')\n" | mail -s "docker_install_nn_cmssw() ERROR rpmdb rebuild failed for $cmssw_release $SCRAM_ARCH" $notifytowhom
            [ "$cvmfs_server_yes" == "yes" ] && ( cd ; cvmfs_server abort -f ; ) ;
            return 1
         fi
      fi
      if [ $status -eq 0 ] ; then
         printf "docker_install_nn_cmssw() cmspkg -a ${SCRAM_ARCH} install -y cms+cmssw${second_plus}+$cmssw_release succeeded after the mutex increase\nContent of $workdir/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log\n$(cat $workdir/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log | sed 's#%#%%#g')\n" | mail -s "docker_install_nn_cmssw() INFO $cmssw_release ${SCRAM_ARCH} installed" $notifytowhom
      else
         printf "docker_install_nn_cmssw() cmspkg -a ${SCRAM_ARCH} install -y cms+cmssw${second_plus}+$cmssw_release failed\n$mutex_error\nContent of $workdir/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log\n$(cat $workdir/logs/cmspkg+${SCRAM_ARCH}+install+cms+cmssw${second_plus}+$cmssw_release.log | sed 's#%#%%#g')\n" | mail -s "docker_install_nn_cmssw() ERROR cmspkg -a ${SCRAM_ARCH} install -y cms+cmssw${second_plus}+$cmssw_release failed" $notifytowhom
         [ "$cvmfs_server_yes" == "yes" ] && ( cd ; cvmfs_server abort -f ; ) ;
         return 1
      fi
   fi
   [ "$cvmfs_server_yes" == "yes" ] && cp $releases_map_local /cvmfs/cms.cern.ch/

   echo INFO cmssw installed: $cmssw_release $SCRAM_ARCH
   return 0
}

function install_cmssw_non_native () {
   
   # 4.0 Check number of arguments
   if [ $# -lt 2 ] ; then
      echo ERROR install_cmssw"()" cmssw scram_arch
      printf "install_cmssw_non_native() cmssw scram_arch\nNot enough number of arguments" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      return 1
   fi
   
   # use cmspkg instead of apt-get
   which cmspkg 2>/dev/null 1>/dev/null
   [ $? -eq 0 ] || { export PATH=$PATH:/cvmfs/cms.cern.ch/common ; } ;

   # 4.1 Check the first argument
   cmssw_release=$1
   export SCRAM_ARCH=$2
   echo "$cmssw_release" | grep -q CMSSW_
   if [ $? -ne 0 ] ; then
      echo ERROR install_cmssw"()" cmssw_release=$cmssw_release does not start with CMSSW_
      printf "install_cmssw() cmssw_release=$cmssw_release does not start with CMSSW_\n" | mail -s "install_cmssw() failed" $notifytowhom
      return 1
   fi
   
   # 4.2 Check the second argument
   echo "$SCRAM_ARCH" | grep -q slc[0-9]
   if [ $? -ne 0 ] ; then
      echo ERROR install_cmssw"()" SCRAM_ARCH=$SCRAM_ARCH does not start with slc
      printf "install_cmssw_non_native() SCRAM_ARCH=$SCRAM_ARCH does not start with slc\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      return 1
   fi

   # 4.3 Check if this is already installed
   thedir=cmssw
   echo $cmssw_release | grep -q patch && thedir=cmssw-patch
   echo INFO checking ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src
   ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src 2>/dev/null 1>/dev/null
   if [ $? -eq 0 ] ; then
      status=1
      echo INFO $cmssw_release $SCRAM_ARCH is already installed
      if [ -f "$db" ] ; then
         grep -q "$cmssw_release ${SCRAM_ARCH}" $db
         if [ $? -ne 0 ] ; then
           echo "$cmssw_release ${SCRAM_ARCH} $(date +%s) $(date)" >> $db
           #status=0
         fi
      fi
      if [ -f "$updated_list" ] ; then
         grep -q "$cmssw_release ${SCRAM_ARCH}" $updated_list
         if [ $? -ne 0 ] ; then
           cvmfs_server transaction
           echo "$cmssw_release ${SCRAM_ARCH} $(date +%s) $(date)" >> $updated_list
           cvmfs_server publish
           status=0
         fi
      fi
      return $status
   fi

   # 4.4 prepare and install it
   second_plus=
   cmssw_release_last_string=$(echo $cmssw_release | sed "s#_# #g" | awk '{print $NF}')

   echo "$cmssw_release_last_string" | grep -q patch && second_plus=-patch

   cd $VO_CMS_SW_DIR
   
   # gcc version
   SCRAM_ARCH_COMPILER=$(echo $SCRAM_ARCH | cut -d_ -f3)
   # corresponding native arch
   SLC_SCRAM_ARCH_DEFAULT=$(/bin/ls -alt /cvmfs/cms.cern.ch | awk '{print $NF}' | grep ^${which_slc}_amd64 | grep "$SCRAM_ARCH_COMPILER" | head -1)
   if [ -f "$(ls -t ${SLC_SCRAM_ARCH_DEFAULT}/external/apt/*/etc/profile.d/init.sh | head -1)" ] ; then
      if [ ! -f "$(ls -t ${SLC_SCRAM_ARCH_DEFAULT}/external/curl/*/etc/profile.d/init.sh | head -1)" ] ; then
         echo Warning using the alternative $(/bin/ls -alt /cvmfs/cms.cern.ch | awk '{print $NF}' | grep ^${which_slc}_ | head -2 | tail -1) instead of $SLC_SCRAM_ARCH_DEFAULT
         SLC_SCRAM_ARCH_DEFAULT=$(/bin/ls -alt /cvmfs/cms.cern.ch | awk '{print $NF}' | grep ^${which_slc}_ | head -2 | tail -1)
      fi
   else
      SLC_SCRAM_ARCH_DEFAULT=$(/bin/ls -alt /cvmfs/cms.cern.ch | awk '{print $NF}' | grep ^${which_slc}_amd64 | head -1)
   fi
   SLC_SCRAM_ARCH=$SLC_SCRAM_ARCH_DEFAULT
   echo INFO which_slc ${which_slc} SLC_SCRAM_ARCH=$SLC_SCRAM_ARCH for the non-native SLC SLC_SCRAM_ARCH_DEFAULT=$SLC_SCRAM_ARCH_DEFAULT
   apt_config=$(ls -t $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/apt.conf | head -1)
   #
   # we need to use the native http binary, which we should do via apt* -c $apt_conf
   # 
   cp ${apt_config} $HOME/apt.conf
   SLC_SCRAM_ARCH_METHODS=$(for d in /cvmfs/cms.cern.ch/${SLC_SCRAM_ARCH}/external/apt/*/lib/apt/methods/   ; do echo $d ; done | head -1)
   
   OSX_SCRAM_ARCH_METHODS=$(grep methods $HOME/apt.conf | cut -d\" -f2 | grep ${SCRAM_ARCH})
   echo DEBUG SLC_SCRAM_ARCH_METHODS=$SLC_SCRAM_ARCH_METHODS
   echo DEBUG OSX_SCRAM_ARCH_METHODS=$OSX_SCRAM_ARCH_METHODS
   sed -i "s#${OSX_SCRAM_ARCH_METHODS}#${SLC_SCRAM_ARCH_METHODS}#g" $HOME/apt.conf

   # this was unnecessary becasue of APT_CONFIG and RPM_CONFIGDIR
   sed -i "s#--ignoreos#--dbpath\";\"$VO_CMS_SW_DIR/${SCRAM_ARCH}/var/lib/rpm\";\"--ignoreos#" $HOME/apt.conf
   echo INFO content of $HOME/apt.conf
   cat $HOME/apt.conf
   apt_config=$HOME/apt.conf 
   apt_init_sh_source_status=1
   if [ -f "$(ls -t ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)" ] ; then
      echo INFO source $(ls -t ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)
      source $(ls -t ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)
      apt_init_sh_source_status=$?
   else
      echo ERROR failed apt init.sh does not exist: ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh
      printf "install_cmssw_non_native() apt init.sh does not exist: ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh\n" | mail -s "$(basename $0) failed" $notifytowhom
      return 1
   fi

   if [ -f "$(ls -t ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)" ] ; then
      # for cvmfs_server
      echo INFO source $(ls -t ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
      source $(ls -t ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
      ldd $(which curl)
      #echo INFO ldd $(which curl) status=$?
      ldd $(which curl) 2>&1 | grep OPENSSL | grep -q "not found"
      if [ $? -eq 0 ] ; then
         echo INFO source $(ls -t ${SLC_SCRAM_ARCH}/external/openssl/*/etc/profile.d/init.sh | head -1)
         source $(ls -t ${SLC_SCRAM_ARCH}/external/openssl/*/etc/profile.d/init.sh | head -1)
      fi
      
      ldd $(which curl) 2>&1 | grep -q "not found"
      if [ $? -eq 0 ] ; then
         echo ERROR failed to set up curl env\nSome library may be missing $(ldd $(which curl))
         printf "install_cmssw()  set up curl env failed\nSome library may be missing\necho ldd $(which curl) result follows\n$(ldd $(which curl))\n" | mail -s "ERROR install_cmssw() set up curl env failed" $notifytowhom
         return 1
      fi
   else
      echo Warning curl init.sh does not exist: ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh
      ldd $(which curl)
      echo INFO ldd $(which curl) status=$?
   fi

   export RPM_CONFIGDIR=$(for d in $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/rpm/*/lib/rpm ; do echo $d ; done | head -1)
   echo INFO using RPM_CONFIGDIR=$RPM_CONFIGDIR

   printf "install_cmssw_non_native() Starting cvmfs_server transaction for $cmssw_release ${SCRAM_ARCH}\n" | mail -s "cvmfs_server transaction started" $notifytowhom
   cvmfs_server transaction
   status=$?
   what="install_cmssw_non_native()_${cmssw_release}_${SCRAM_ARCH}"
   cvmfs_server_transaction_check $status $what
   if [ $? -eq 0 ] ; then
      echo INFO transaction OK for $what
   else
      printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom
      return 1
   fi
   printf "install_cmssw_non_native() \nUsing $(which apt-get) for $cmssw_release and $SCRAM_ARCH\n" | mail -s "install_cmssw_non_native()" $notifytowhom

   thetimeout=300

   echo INFO checking cvmfs_server list to see if it is in transaction
   cvmfs_server list  | grep stratum0 2>&1

   echo INFO executing apt-get --assume-yes -c=$apt_config update for $cmssw_release ${SCRAM_ARCH}  
   apt-get --assume-yes -c=$apt_config update >& $HOME/apt_get_update.log &
   theps=$!
   timeout_encountered=0
   i=0
   while : ; do
         #echo DEBUG Doing check if rpm -qa process is ended $i
         if [ $i -gt $thetimeout ] ; then
            ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
            [ $? -eq 0 ] && { kill $theps ; echo Warning $theps killed ; } ;
            timeout_encountered=1
            break
         fi
         ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
         [ $? -eq 0 ] || { echo INFO $theps finished within time ; break ; } ;
         i=$(expr $i + 1)
         sleep 1
   done
   wait $theps
   status=$?
   if [ $status -ne 0 ] ; then
      echo Warning apt-get --assume-yes -c=$apt_config update failed running it in foreground
      cvmfs_server list  | grep stratum0 2>&1 | grep -q "in transaction"
      [ $? -eq 0 ] || { echo Warning strange running cvmfs_server transaction again ; cvmfs_server transaction ; } ;
      apt-get --assume-yes -c=$apt_config update
      status=$?
   fi
   cat $HOME/apt_get_update.log
   cp $HOME/apt_get_update.log $HOME/logs/apt_get_update+${cmssw_release}+${SCRAM_ARCH}.log
   if [ $timeout_encountered -ne 0 ] ; then
      printf "install_cmssw_non_native() apt-get updated timed out\n$(cat  $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() apt-get update timed out" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
  
   if [ $status -ne 0 ] ; then
      echo ERROR failed apt-get update
      printf "install_cmssw_non_native() apt-get update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   grep -q -i "^error: " $HOME/apt_get_update.log
   if [ $? -eq 0 ] ; then
      echo ERROR failed apt-get update
      printf "install_cmssw_non_native() apt-get update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   grep -q -i "^E: " $HOME/apt_get_update.log
   if [ $? -eq 0 ] ; then
      echo ERROR failed apt-get update
      printf "install_cmssw_non_native() apt-get update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   echo DEBUG checking fakesystem
   rpm -qa --dbpath /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm | grep fakesystem
   if [ $(rpm -qa --dbpath /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm | grep -q fakesystem ; echo $? ) -ne 0 ] ; then
      fakesystems=$(apt-cache pkgnames | grep fakesystem)
      echo INFO installing fakes $fakesystems
      #printf "install_cmssw_non_native() installing fakesystems\n" | mail -s "install_cmssw_non_native() installing fakesystems" $notifytowhom
      apt-get --assume-yes -c=$apt_config install $fakesystems >& $HOME/apt_get_install_fakesystems.log &
      theps=$!
      timeout_encountered=0
      i=0
      while : ; do
         #echo DEBUG Doing check if rpm -qa process is ended $i
         if [ $i -gt $thetimeout ] ; then
            ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
            [ $? -eq 0 ] && { kill $theps ; echo Warning $theps killed ; } ;
            timeout_encountered=1
            break
         fi
         ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
         [ $? -eq 0 ] || { echo INFO $theps finished within time ; break ; } ;
         i=$(expr $i + 1)
         sleep 1
      done
      wait $theps
      status=$?
      if [ $timeout_encountered -ne 0 ] ; then
         printf "install_cmssw_non_native() apt-get install fakesystem timed out\n$(cat   $HOME/apt_get_install_fakesystems.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() apt-get install fakesystem timed out" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         return 1
      fi
      [ $status -eq 0 ] || { echo fakesystems install failed ; printf "install_cmssw_non_native() apt-get install fakesystem failed\n$(cat   $HOME/apt_get_install_fakesystems.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() apt-get install fakesystem failed" $notifytowhom ; cd ; cvmfs_server abort -f ; return 1 ; } ;
   fi

   thetimeout=7200

   echo INFO installing $cmssw_release ${SCRAM_ARCH} via apt-get --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$cmssw_release
   #printf "install_cmssw_non_native() apt-get install started\n" | mail -s "install_cmssw_non_native() apt-get install started" $notifytowhom
   apt-get --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$cmssw_release >& $HOME/apt_get_install.log &
   theps=$!
   timeout_encountered=0
   i=0
   while : ; do
         #echo DEBUG Doing check if rpm -qa process is ended $i
         if [ $i -gt $thetimeout ] ; then
            ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
            [ $? -eq 0 ] && { kill $theps ; echo Warning $theps killed ; } ;
            timeout_encountered=1
            break
         fi
         ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
         [ $? -eq 0 ] || { echo INFO $theps finished within time ; break ; } ;
         i=$(expr $i + 1)
         sleep 1
   done
   wait $theps
   status=$?
   cp $HOME/apt_get_install.log $HOME/logs/apt_get_install+${cmssw_release}+${SCRAM_ARCH}.log

   if [ $timeout_encountered -ne 0 ] ; then
      printf "install_cmssw_non_native() apt-get install timed out\n$(cat  $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() apt-get install timed out" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   grep -A 100 -B 100 "W: Bizarre Error - File size is not what the server reported" $HOME/apt_get_install.log | grep -q "E: Unable to fetch some archives"
   if [ $? -eq 0 ] ; then
      echo DEBUG we will try to install apt
      apt-get --assume-yes -c=$apt_config install external+apt+0.5.16 2>&1 | tee $HOME/apt_get_install_external+apt.log
      source $(ls -t ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)     
      status_init=$?
      # for cvmfs_server
      source $(ls -t ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
      ldd $(which curl)
      #echo INFO ldd $(which curl) status=$?
      ldd $(which curl) 2>&1 | grep OPENSSL | grep -q "not found"
      if [ $? -eq 0 ] ; then
         source $(ls -t ${SLC_SCRAM_ARCH}/external/openssl/*/etc/profile.d/init.sh | head -1)
      fi
      
      ldd $(which curl) 2>&1 | grep -q "not found"
      if [ $? -eq 0 ] ; then
         echo ERROR failed to set up curl env\nSome library may be missing $(ldd $(which curl))
         printf "install_cmssw()  set up curl env failed\nSome library may be missing\necho ldd $(which curl) result follows\n$(ldd $(which curl))\n" | mail -s "ERROR install_cmssw() set up curl env failed" $notifytowhom
         return 1
      fi

      # unfix NSS mess
      #THE_NSS_PATH=$(for p in $(echo $LD_LIBRARY_PATH | sed 's#:# #g') ; do echo $p | grep /cvmfs/cms.cern.ch/${SLC_SCRAM_ARCH}/external/nss/ ; done | sort -u)
      #export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed -e "s#$THE_NSS_PATH:##g" | sed -e "s#:$THE_NSS_PATH##g")

      echo DEBUG status_init=$status_init which apt-get
      which apt-get 2>&1

      echo INFO executing apt-get --assume-yes update for $cmssw_release ${SCRAM_ARCH}
      apt-get --assume-yes -c=$apt_config update > $HOME/apt_get_update.log 2>&1 # 2>&1 | tee $HOME/apt_get_update.log
      if [ $? -ne 0 ] ; then
         echo ERROR failed apt-get update
         printf "install_cmssw_non_native() 2 apt-get update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         return 1
      fi

      grep -q -i "^error: " $HOME/apt_get_update.log
      if [ $? -eq 0 ] ; then
         echo ERROR failed apt-get update
         printf "install_cmssw_non_native() 2 apt-get update failed for $cmssw_release $SCRAM_ARCH\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         return 1
      fi

      grep -q -i "^E: " $HOME/apt_get_update.log
      if [ $? -eq 0 ] ; then
         echo ERROR failed apt-get update
         printf "install_cmssw_non_native() 2 apt-get update failed for $cmssw_release $SCRAM_ARCH\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         return 1
      fi

      echo INFO executing CMSSW install again
      apt-get --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$cmssw_release > $HOME/apt_get_install.log 2>&1 # 2>&1 | tee $HOME/apt_get_install.log
      status=$?
   fi

   grep -q -i "^error: " $HOME/apt_get_install.log
   if [ $? -eq 0 ] ; then
      printf "install_cmssw_non_native() apt-get install failed for $cmssw_release $SCRAM_ARCH\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   grep -q -i "^E: " $HOME/apt_get_install.log
   if [ $? -eq 0 ] ; then
      printf "install_cmssw_non_native() apt-get install failed for $cmssw_release $SCRAM_ARCH \n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src 2>/dev/null 1>/dev/null
   if [ $? -ne 0 ] ; then
      echo ERROR strangely $cmssw_release $SCRAM_ARCH is not installed
      printf "install_cmssw_non_native() apt-get install failed for $cmssw_release $SCRAM_ARCH\nCheck ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src\n$(ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src)\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   if [ $status -eq 0 ] ; then
      printf "install_cmssw_non_native() $cmssw_release $SCRAM_ARCH installed from $(/bin/hostname -f)\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "[1] install_cmssw_non_native() $cmssw_release INSTALLED" $notifytowhom
   else
      echo ERROR failed apt-get install
      printf "install_cmssw_non_native() apt-get install failed for $cmssw_release $SCRAM_ARCH\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "[1] install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
   
   cp $releases_map_local /cvmfs/cms.cern.ch/

   echo INFO cmssw installed: $cmssw_release $SCRAM_ARCH
   return 0
}

function docker_install_cmssw_slc7 () { # not used any more
   
   # 4.0 Check number of arguments
   if [ $# -lt 2 ] ; then
      echo ERROR docker_install_cmssw_slc7"()" cmssw scram_arch
      printf "docker_install_cmssw_slc7() cmssw scram_arch\nNot enough number of arguments" | mail -s "docker_install_cmssw_slc7() failed" $notifytowhom
      return 1
   fi
   
   # use cmspkg instead of apt-get
   which cmspkg 2>/dev/null 1>/dev/null
   [ $? -eq 0 ] || { export PATH=$PATH:/cvmfs/cms.cern.ch/common ; } ;

   # 4.1 Check the first argument
   cmssw_release=$1
   export SCRAM_ARCH=$2
   echo "$cmssw_release" | grep -q CMSSW_
   if [ $? -ne 0 ] ; then
      echo ERROR install_cmssw"()" cmssw_release=$cmssw_release does not start with CMSSW_
      printf "docker_install_cmssw_slc7() cmssw_release=$cmssw_release does not start with CMSSW_\n" | mail -s "docker_install_cmssw_slc7() failed" $notifytowhom
      return 1
   fi
   
   # 4.2 Check the second argument
   echo "$SCRAM_ARCH" | grep -q slc[0-9]
   if [ $? -ne 0 ] ; then
      echo ERROR install_cmssw"()" SCRAM_ARCH=$SCRAM_ARCH does not start with slc
      printf "docker_install_cmssw_slc7() SCRAM_ARCH=$SCRAM_ARCH does not start with slc\n" | mail -s "docker_install_cmssw_slc7() failed" $notifytowhom
      return 1
   fi

   # 4.3 Check if this is already installed
   thedir=cmssw
   echo $cmssw_release | grep -q patch && thedir=cmssw-patch
   echo INFO checking ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src
   ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src 2>/dev/null 1>/dev/null
   if [ $? -eq 0 ] ; then
      status=1
      echo INFO $cmssw_release $SCRAM_ARCH is already installed
      if [ -f "$db" ] ; then
         grep -q "$cmssw_release ${SCRAM_ARCH}" $db
         if [ $? -ne 0 ] ; then
           echo "$cmssw_release ${SCRAM_ARCH} $(date +%s) $(date)" >> $db
           #status=0
         fi
      fi
      if [ -f "$updated_list" ] ; then
         grep -q "$cmssw_release ${SCRAM_ARCH}" $updated_list
         if [ $? -ne 0 ] ; then
           cvmfs_server transaction
           echo "$cmssw_release ${SCRAM_ARCH} $(date +%s) $(date)" >> $updated_list
           cvmfs_server publish
           status=0
         fi
      fi
      return $status
   fi

   # 4.4 prepare and install it
   second_plus=
   cmssw_release_last_string=$(echo $cmssw_release | sed "s#_# #g" | awk '{print $NF}')

   echo "$cmssw_release_last_string" | grep -q patch && second_plus=-patch

   echo Check Point docker_install_cmssw_slc7
   # Implement it here
   return 0

   cd $VO_CMS_SW_DIR
   
   # gcc version
   SCRAM_ARCH_COMPILER=$(echo $SCRAM_ARCH | cut -d_ -f3)
   # corresponding native arch
   SLC_SCRAM_ARCH_DEFAULT=$(/bin/ls -alt /cvmfs/cms.cern.ch | awk '{print $NF}' | grep ^${which_slc}_amd64 | grep "$SCRAM_ARCH_COMPILER" | head -1)
   if [ -f "$(ls -t ${SLC_SCRAM_ARCH_DEFAULT}/external/apt/*/etc/profile.d/init.sh | head -1)" ] ; then
      if [ ! -f "$(ls -t ${SLC_SCRAM_ARCH_DEFAULT}/external/curl/*/etc/profile.d/init.sh | head -1)" ] ; then
         echo Warning using the alternative $(/bin/ls -alt /cvmfs/cms.cern.ch | awk '{print $NF}' | grep ^${which_slc}_ | head -2 | tail -1) instead of $SLC_SCRAM_ARCH_DEFAULT
         SLC_SCRAM_ARCH_DEFAULT=$(/bin/ls -alt /cvmfs/cms.cern.ch | awk '{print $NF}' | grep ^${which_slc}_ | head -2 | tail -1)
      fi
   else
      SLC_SCRAM_ARCH_DEFAULT=$(/bin/ls -alt /cvmfs/cms.cern.ch | awk '{print $NF}' | grep ^${which_slc}_amd64 | head -1)
   fi
   SLC_SCRAM_ARCH=$SLC_SCRAM_ARCH_DEFAULT
   echo INFO which_slc ${which_slc} SLC_SCRAM_ARCH=$SLC_SCRAM_ARCH for the non-native SLC SLC_SCRAM_ARCH_DEFAULT=$SLC_SCRAM_ARCH_DEFAULT
   apt_config=$(ls -t $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/apt.conf | head -1)
   #
   # we need to use the native http binary, which we should do via apt* -c $apt_conf
   # 
   cp ${apt_config} $HOME/apt.conf
   SLC_SCRAM_ARCH_METHODS=$(for d in /cvmfs/cms.cern.ch/${SLC_SCRAM_ARCH}/external/apt/*/lib/apt/methods/   ; do echo $d ; done | head -1)
   
   OSX_SCRAM_ARCH_METHODS=$(grep methods $HOME/apt.conf | cut -d\" -f2 | grep ${SCRAM_ARCH})
   echo DEBUG SLC_SCRAM_ARCH_METHODS=$SLC_SCRAM_ARCH_METHODS
   echo DEBUG OSX_SCRAM_ARCH_METHODS=$OSX_SCRAM_ARCH_METHODS
   sed -i "s#${OSX_SCRAM_ARCH_METHODS}#${SLC_SCRAM_ARCH_METHODS}#g" $HOME/apt.conf

   # this was unnecessary becasue of APT_CONFIG and RPM_CONFIGDIR
   sed -i "s#--ignoreos#--dbpath\";\"$VO_CMS_SW_DIR/${SCRAM_ARCH}/var/lib/rpm\";\"--ignoreos#" $HOME/apt.conf
   echo INFO content of $HOME/apt.conf
   cat $HOME/apt.conf
   apt_config=$HOME/apt.conf 
   apt_init_sh_source_status=1
   if [ -f "$(ls -t ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)" ] ; then
      echo INFO source $(ls -t ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)
      source $(ls -t ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)
      apt_init_sh_source_status=$?
   else
      echo ERROR failed apt init.sh does not exist: ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh
      printf "install_cmssw_non_native() apt init.sh does not exist: ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh\n" | mail -s "$(basename $0) failed" $notifytowhom
      return 1
   fi

   if [ -f "$(ls -t ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)" ] ; then
      # for cvmfs_server
      echo INFO source $(ls -t ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
      source $(ls -t ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
      ldd $(which curl)
      #echo INFO ldd $(which curl) status=$?
      ldd $(which curl) 2>&1 | grep OPENSSL | grep -q "not found"
      if [ $? -eq 0 ] ; then
         echo INFO source $(ls -t ${SLC_SCRAM_ARCH}/external/openssl/*/etc/profile.d/init.sh | head -1)
         source $(ls -t ${SLC_SCRAM_ARCH}/external/openssl/*/etc/profile.d/init.sh | head -1)
      fi
      
      ldd $(which curl) 2>&1 | grep -q "not found"
      if [ $? -eq 0 ] ; then
         echo ERROR failed to set up curl env\nSome library may be missing $(ldd $(which curl))
         printf "install_cmssw()  set up curl env failed\nSome library may be missing\necho ldd $(which curl) result follows\n$(ldd $(which curl))\n" | mail -s "ERROR install_cmssw() set up curl env failed" $notifytowhom
         return 1
      fi
   else
      echo Warning curl init.sh does not exist: ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh
      ldd $(which curl)
      echo INFO ldd $(which curl) status=$?
   fi

   export RPM_CONFIGDIR=$(for d in $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/rpm/*/lib/rpm ; do echo $d ; done | head -1)
   echo INFO using RPM_CONFIGDIR=$RPM_CONFIGDIR

   printf "install_cmssw_non_native() Starting cvmfs_server transaction for $cmssw_release ${SCRAM_ARCH}\n" | mail -s "cvmfs_server transaction started" $notifytowhom
   cvmfs_server transaction
   status=$?
   what="install_cmssw_non_native()_${cmssw_release}_${SCRAM_ARCH}"
   cvmfs_server_transaction_check $status $what
   if [ $? -eq 0 ] ; then
      echo INFO transaction OK for $what
   else
      printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom
      return 1
   fi
   printf "install_cmssw_non_native() \nUsing $(which apt-get) for $cmssw_release and $SCRAM_ARCH\n" | mail -s "install_cmssw_non_native()" $notifytowhom

   thetimeout=300

   echo INFO checking cvmfs_server list to see if it is in transaction
   cvmfs_server list  | grep stratum0 2>&1

   echo INFO executing apt-get --assume-yes -c=$apt_config update for $cmssw_release ${SCRAM_ARCH}  
   apt-get --assume-yes -c=$apt_config update >& $HOME/apt_get_update.log &
   theps=$!
   timeout_encountered=0
   i=0
   while : ; do
         #echo DEBUG Doing check if rpm -qa process is ended $i
         if [ $i -gt $thetimeout ] ; then
            ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
            [ $? -eq 0 ] && { kill $theps ; echo Warning $theps killed ; } ;
            timeout_encountered=1
            break
         fi
         ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
         [ $? -eq 0 ] || { echo INFO $theps finished within time ; break ; } ;
         i=$(expr $i + 1)
         sleep 1
   done
   wait $theps
   status=$?
   if [ $status -ne 0 ] ; then
      echo Warning apt-get --assume-yes -c=$apt_config update failed running it in foreground
      cvmfs_server list  | grep stratum0 2>&1 | grep -q "in transaction"
      [ $? -eq 0 ] || { echo Warning strange running cvmfs_server transaction again ; cvmfs_server transaction ; } ;
      apt-get --assume-yes -c=$apt_config update
      status=$?
   fi
   cat $HOME/apt_get_update.log
   cp $HOME/apt_get_update.log $HOME/logs/apt_get_update+${cmssw_release}+${SCRAM_ARCH}.log
   if [ $timeout_encountered -ne 0 ] ; then
      printf "install_cmssw_non_native() apt-get updated timed out\n$(cat  $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() apt-get update timed out" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
  
   if [ $status -ne 0 ] ; then
      echo ERROR failed apt-get update
      printf "install_cmssw_non_native() apt-get update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   grep -q -i "^error: " $HOME/apt_get_update.log
   if [ $? -eq 0 ] ; then
      echo ERROR failed apt-get update
      printf "install_cmssw_non_native() apt-get update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   grep -q -i "^E: " $HOME/apt_get_update.log
   if [ $? -eq 0 ] ; then
      echo ERROR failed apt-get update
      printf "install_cmssw_non_native() apt-get update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   echo DEBUG checking fakesystem
   rpm -qa --dbpath /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm | grep fakesystem
   if [ $(rpm -qa --dbpath /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm | grep -q fakesystem ; echo $? ) -ne 0 ] ; then
      fakesystems=$(apt-cache pkgnames | grep fakesystem)
      echo INFO installing fakes $fakesystems
      #printf "install_cmssw_non_native() installing fakesystems\n" | mail -s "install_cmssw_non_native() installing fakesystems" $notifytowhom
      apt-get --assume-yes -c=$apt_config install $fakesystems >& $HOME/apt_get_install_fakesystems.log &
      theps=$!
      timeout_encountered=0
      i=0
      while : ; do
         #echo DEBUG Doing check if rpm -qa process is ended $i
         if [ $i -gt $thetimeout ] ; then
            ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
            [ $? -eq 0 ] && { kill $theps ; echo Warning $theps killed ; } ;
            timeout_encountered=1
            break
         fi
         ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
         [ $? -eq 0 ] || { echo INFO $theps finished within time ; break ; } ;
         i=$(expr $i + 1)
         sleep 1
      done
      wait $theps
      status=$?
      if [ $timeout_encountered -ne 0 ] ; then
         printf "install_cmssw_non_native() apt-get install fakesystem timed out\n$(cat   $HOME/apt_get_install_fakesystems.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() apt-get install fakesystem timed out" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         return 1
      fi
      [ $status -eq 0 ] || { echo fakesystems install failed ; printf "install_cmssw_non_native() apt-get install fakesystem failed\n$(cat   $HOME/apt_get_install_fakesystems.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() apt-get install fakesystem failed" $notifytowhom ; cd ; cvmfs_server abort -f ; return 1 ; } ;
   fi

   thetimeout=7200

   echo INFO installing $cmssw_release ${SCRAM_ARCH} via apt-get --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$cmssw_release
   #printf "install_cmssw_non_native() apt-get install started\n" | mail -s "install_cmssw_non_native() apt-get install started" $notifytowhom
   apt-get --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$cmssw_release >& $HOME/apt_get_install.log &
   theps=$!
   timeout_encountered=0
   i=0
   while : ; do
         #echo DEBUG Doing check if rpm -qa process is ended $i
         if [ $i -gt $thetimeout ] ; then
            ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
            [ $? -eq 0 ] && { kill $theps ; echo Warning $theps killed ; } ;
            timeout_encountered=1
            break
         fi
         ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
         [ $? -eq 0 ] || { echo INFO $theps finished within time ; break ; } ;
         i=$(expr $i + 1)
         sleep 1
   done
   wait $theps
   status=$?
   cp $HOME/apt_get_install.log $HOME/logs/apt_get_install+${cmssw_release}+${SCRAM_ARCH}.log

   if [ $timeout_encountered -ne 0 ] ; then
      printf "install_cmssw_non_native() apt-get install timed out\n$(cat  $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() apt-get install timed out" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   grep -A 100 -B 100 "W: Bizarre Error - File size is not what the server reported" $HOME/apt_get_install.log | grep -q "E: Unable to fetch some archives"
   if [ $? -eq 0 ] ; then
      echo DEBUG we will try to install apt
      apt-get --assume-yes -c=$apt_config install external+apt+0.5.16 2>&1 | tee $HOME/apt_get_install_external+apt.log
      source $(ls -t ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)     
      status_init=$?
      # for cvmfs_server
      source $(ls -t ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
      ldd $(which curl)
      #echo INFO ldd $(which curl) status=$?
      ldd $(which curl) 2>&1 | grep OPENSSL | grep -q "not found"
      if [ $? -eq 0 ] ; then
         source $(ls -t ${SLC_SCRAM_ARCH}/external/openssl/*/etc/profile.d/init.sh | head -1)
      fi
      
      ldd $(which curl) 2>&1 | grep -q "not found"
      if [ $? -eq 0 ] ; then
         echo ERROR failed to set up curl env\nSome library may be missing $(ldd $(which curl))
         printf "install_cmssw()  set up curl env failed\nSome library may be missing\necho ldd $(which curl) result follows\n$(ldd $(which curl))\n" | mail -s "ERROR install_cmssw() set up curl env failed" $notifytowhom
         return 1
      fi

      # unfix NSS mess
      #THE_NSS_PATH=$(for p in $(echo $LD_LIBRARY_PATH | sed 's#:# #g') ; do echo $p | grep /cvmfs/cms.cern.ch/${SLC_SCRAM_ARCH}/external/nss/ ; done | sort -u)
      #export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed -e "s#$THE_NSS_PATH:##g" | sed -e "s#:$THE_NSS_PATH##g")

      echo DEBUG status_init=$status_init which apt-get
      which apt-get 2>&1

      echo INFO executing apt-get --assume-yes update for $cmssw_release ${SCRAM_ARCH}
      apt-get --assume-yes -c=$apt_config update > $HOME/apt_get_update.log 2>&1 # 2>&1 | tee $HOME/apt_get_update.log
      if [ $? -ne 0 ] ; then
         echo ERROR failed apt-get update
         printf "install_cmssw_non_native() 2 apt-get update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         return 1
      fi

      grep -q -i "^error: " $HOME/apt_get_update.log
      if [ $? -eq 0 ] ; then
         echo ERROR failed apt-get update
         printf "install_cmssw_non_native() 2 apt-get update failed for $cmssw_release $SCRAM_ARCH\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         return 1
      fi

      grep -q -i "^E: " $HOME/apt_get_update.log
      if [ $? -eq 0 ] ; then
         echo ERROR failed apt-get update
         printf "install_cmssw_non_native() 2 apt-get update failed for $cmssw_release $SCRAM_ARCH\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         return 1
      fi

      echo INFO executing CMSSW install again
      apt-get --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$cmssw_release > $HOME/apt_get_install.log 2>&1 # 2>&1 | tee $HOME/apt_get_install.log
      status=$?
   fi

   grep -q -i "^error: " $HOME/apt_get_install.log
   if [ $? -eq 0 ] ; then
      printf "install_cmssw_non_native() apt-get install failed for $cmssw_release $SCRAM_ARCH\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   grep -q -i "^E: " $HOME/apt_get_install.log
   if [ $? -eq 0 ] ; then
      printf "install_cmssw_non_native() apt-get install failed for $cmssw_release $SCRAM_ARCH \n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src 2>/dev/null 1>/dev/null
   if [ $? -ne 0 ] ; then
      echo ERROR strangely $cmssw_release $SCRAM_ARCH is not installed
      printf "install_cmssw_non_native() apt-get install failed for $cmssw_release $SCRAM_ARCH\nCheck ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src\n$(ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src)\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi

   if [ $status -eq 0 ] ; then
      printf "install_cmssw_non_native() $cmssw_release $SCRAM_ARCH installed from $(/bin/hostname -f)\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "[1] install_cmssw_non_native() $cmssw_release INSTALLED" $notifytowhom
   else
      echo ERROR failed apt-get install
      printf "install_cmssw_non_native() apt-get install failed for $cmssw_release $SCRAM_ARCH\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "[1] install_cmssw_non_native() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
   
   cp $releases_map_local /cvmfs/cms.cern.ch/

   echo INFO cmssw installed: $cmssw_release $SCRAM_ARCH
   return 0
}

function install_cmssw_osx () {
   
   # 4.0 Check number of arguments
   if [ $# -lt 2 ] ; then
      echo ERROR install_cmssw"()" cmssw scram_arch
      printf "install_cmssw_osx() cmssw scram_arch\nNot enough number of arguments" | mail -s "install_cmssw_osx() failed" $notifytowhom
      return 1
   fi
   
   # use cmspkg instead of apt-get
   which cmspkg 2>/dev/null 1>/dev/null
   [ $? -eq 0 ] || { export PATH=$PATH:/cvmfs/cms.cern.ch/common ; } ;

   # 4.1 Check the first argument
   cmssw_release=$1
   export SCRAM_ARCH=$2
   echo "$cmssw_release" | grep -q CMSSW_
   if [ $? -ne 0 ] ; then
      echo ERROR install_cmssw"()" cmssw_release=$cmssw_release does not start with CMSSW_
      printf "install_cmssw() cmssw_release=$cmssw_release does not start with CMSSW_\n" | mail -s "install_cmssw() failed" $notifytowhom
      return 1
   fi
   
   # 4.2 Check the second argument
   echo "$SCRAM_ARCH" | grep -q osx[0-9]
   if [ $? -ne 0 ] ; then
      echo ERROR install_cmssw"()" SCRAM_ARCH=$SCRAM_ARCH does not start with osx
      printf "install_cmssw_osx() SCRAM_ARCH=$SCRAM_ARCH does not start with osx\n" | mail -s "install_cmssw_osx() failed" $notifytowhom
      return 1
   fi

   # 4.3 Check if this is already installed
   thedir=cmssw
   echo $cmssw_release | grep -q patch && thedir=cmssw-patch
   echo INFO checking ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src
   ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src 2>/dev/null 1>/dev/null
   if [ $? -eq 0 ] ; then
      status=1
      echo INFO $cmssw_release $SCRAM_ARCH is already installed
      if [ -f "$db" ] ; then
         grep -q "$cmssw_release ${SCRAM_ARCH}" $db
         if [ $? -ne 0 ] ; then
           #echo "$cmssw_release ${SCRAM_ARCH}" >> $db
           echo "$cmssw_release ${SCRAM_ARCH} $(date +%s) $(date)" >> $db
           #status=0
         fi
      fi
      if [ -f "$updated_list" ] ; then
         grep -q "$cmssw_release ${SCRAM_ARCH}" $updated_list
         if [ $? -ne 0 ] ; then
           #echo "$cmssw_release ${SCRAM_ARCH}" >> $db
           cvmfs_server transaction
           echo "$cmssw_release ${SCRAM_ARCH} $(date +%s) $(date)" >> $updated_list
           cvmfs_server publish
           #status=0
         fi
      fi
      return $status
   fi

   # 4.4 prepare and install it
   second_plus=
   cmssw_release_last_string=$(echo $cmssw_release | sed "s#_# #g" | awk '{print $NF}')

   echo "$cmssw_release_last_string" | grep -q patch && second_plus=-patch

   cd $VO_CMS_SW_DIR
   # FIXME: we need to install apt-get 0.5.16 for all SCRAM_ARCH to make the following generic line work <-- FIXED
   SLC_SCRAM_ARCH_DEFAULT=${which_slc}_$(echo ${SCRAM_ARCH} | cut -d_ -f2,3)
   SLC_SCRAM_ARCH=slc6_amd64_gcc491
   #SLC_SCRAM_ARCH_DEFAULT=$(/bin/ls -alt /cvmfs/cms.cern.ch | awk '{print $NF}' | grep ^${which_slc}* | head -1)
   
   echo DEBUG we will use $SLC_SCRAM_ARCH
   apt_config=$(ls -t $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/apt.conf | head -1)
   #apt_config=$(ls -t $VO_CMS_SW_DIR/${SLC_SCRAM_ARCH}/external/apt/*/etc/apt.conf | head -1)
   [ -f ${apt_config}.original ] || cp ${apt_config} ${apt_config}.original
   cp ${apt_config}.original $HOME/apt.conf
   SLC_SCRAM_ARCH_METHODS=$(for d in /cvmfs/cms.cern.ch/${SLC_SCRAM_ARCH}/external/apt/*/lib/apt/methods/   ; do echo $d ; done | head -1)
   OSX_SCRAM_ARCH_METHODS=$(grep methods $HOME/apt.conf | cut -d\" -f2 | grep ${SCRAM_ARCH})
   echo DEBUG SLC_SCRAM_ARCH_METHODS=$SLC_SCRAM_ARCH_METHODS
   echo DEBUG OSX_SCRAM_ARCH_METHODS=$OSX_SCRAM_ARCH_METHODS
   sed -i "s#${OSX_SCRAM_ARCH_METHODS}#${SLC_SCRAM_ARCH_METHODS}#g" $HOME/apt.conf
   # this was unnecessary becasue of APT_CONFIG and RPM_CONFIGDIR
   sed -i "s#--ignoreos#--dbpath\";\"$VO_CMS_SW_DIR/${SCRAM_ARCH}/var/lib/rpm\";\"--ignoreos#" $HOME/apt.conf
   echo DEBUG cat $HOME/apt.conf
   cat $HOME/apt.conf
   apt_config=$HOME/apt.conf 
   if [ -f "$(ls -t ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)" ] ; then
      echo DEBUG using $(ls -t ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)
      source $(ls -t ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)
      # for cvmfs_server
      source $(ls -t ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
      ldd $(which curl)
      #echo INFO ldd $(which curl) status=$?
      ldd $(which curl) 2>&1 | grep OPENSSL | grep -q "not found"
      if [ $? -eq 0 ] ; then
         source $(ls -t ${SLC_SCRAM_ARCH}/external/openssl/*/etc/profile.d/init.sh | head -1)
      fi
      
      ldd $(which curl) 2>&1 | grep -q "not found"
      if [ $? -eq 0 ] ; then
         echo ERROR failed to set up curl env\nSome library may be missing $(ldd $(which curl))
         printf "install_cmssw()  set up curl env failed\nSome library may be missing\necho ldd $(which curl) result follows\n$(ldd $(which curl))\n" | mail -s "ERROR install_cmssw() set up curl env failed" $notifytowhom
         return 1
      fi
      # unfix NSS mess
      #THE_NSS_PATH=$(for p in $(echo $LD_LIBRARY_PATH | sed 's#:# #g') ; do echo $p | grep /cvmfs/cms.cern.ch/${SLC_SCRAM_ARCH}/external/nss/ ; done | sort -u)
      #export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed -e "s#$THE_NSS_PATH:##g" | sed -e "s#:$THE_NSS_PATH##g")

   else
      echo ERROR failed apt init.sh does not exist: ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh
      printf "install_cmssw_osx() apt init.sh does not exist: ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh\n" | mail -s "$(basename $0) failed" $notifytowhom
      return 1
   fi

   if [ $? -ne 0 ] ; then
      echo ERROR failed sourcing apt init.sh
      printf "install_cmssw_osx() sourceing apt init.sh failed\n" | mail -s "install_cmssw_osx() failed" $notifytowhom
      return 1
   fi

   # New that we sourced the SLC apt init.sh
   export RPM_CONFIGDIR=$(for d in $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/rpm/*/lib/rpm ; do echo $d ; done | head -1)
   echo DEBUG using RPM_CONFIGDIR=$RPM_CONFIGDIR

   #echo DEBUG checking rpm -qa
   #rpm -qa

   printf "install_cmssw_osx() Starting cvmfs_server transaction for $cmssw_release ${SCRAM_ARCH}\n" | mail -s "cvmfs_server transaction started" $notifytowhom
   cvmfs_server transaction
   status=$?
   what="install_cmssw_osx()_${cmssw_release}_${SCRAM_ARCH}"
   cvmfs_server_transaction_check $status $what
   if [ $? -eq 0 ] ; then
      echo INFO transaction OK for $what
   else
      printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom
      return 1
   fi
   printf "install_cmssw_osx() \nUsing $(which apt-get) for $cmssw_release and $SCRAM_ARCH\n" | mail -s "install_cmssw_osx()" $notifytowhom
   # 17SEP2014
   if [ "x$cvmfs_server_yes" == "xyes" ] ; then
        echo INFO rpmdb needs to be small/local on the cvmfs server, create a softlink that is backed up
        ( cd $VO_CMS_SW_DIR/${SCRAM_ARCH}/var/lib
          if [ ! -d rpm ] ; then
              if [ -L rpm ] ; then
                 mv rpm rpm.CVMFS_SLC6_MIGRATION
              fi
          fi
        )
   fi

#if [ ] ; then
   #echo $cmssw_release $SCRAM_ARCH at $(date -u) > $HOME/rpmdb_rebuild.log
   thetimeout=300
   #printf "install_cmssw_osx() rpmdb rebuild started\n" | mail -s "install_cmssw_osx() rpmdb rebuild started" $notifytowhom
   echo INFO rebuilding rpmdb $cmssw_release $SCRAM_ARCH at $(date -u)
   rm -f /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/__db.00{1,2,3}
   rpmdb --define "_rpmlock_path /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm/lock" --rebuilddb --dbpath /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm >& $HOME/rpmdb_rebuild.log &
   theps=$!
   timeout_encountered=0
   i=0
   while : ; do
         #echo DEBUG Doing check if rpm -qa process is ended $i
         if [ $i -gt $thetimeout ] ; then
            ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
            [ $? -eq 0 ] && { kill $theps ; echo Warning $theps killed ; } ;
            timeout_encountered=1
            break
         fi
         ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
         [ $? -eq 0 ] || { echo INFO $theps finished within time ; break ; } ;
         i=$(expr $i + 1)
         sleep 1
   done
   wait $theps
   status=$?
   if [ $timeout_encountered -ne 0 ] ; then
      printf "install_cmssw_osx() rpmdb rebuild timed out\n$(cat  $HOME/rpmdb_rebuild.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() rpmdb rebuild timed out" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
   if [ $status -ne 0 ] ; then
      printf "install_cmssw_osx() rpmdb rebuild failed\n$(cat  $HOME/rpmdb_rebuild.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() rpmdb rebuild failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
#fi # if [ ] ; then

   echo INFO executing apt-get --assume-yes -c=$apt_config update for $cmssw_release ${SCRAM_ARCH}  
   #echo INFO executing apt-get --assume-yes -c=$apt_config update for $cmssw_release ${SCRAM_ARCH} at $(date -u) > $HOME/apt_get_update.log
   #printf "install_cmssw_osx() apt-get update started\n" | mail -s "install_cmssw_osx() apt-get update started" $notifytowhom
   apt-get --assume-yes -c=$apt_config update >& $HOME/apt_get_update.log &
   theps=$!
   timeout_encountered=0
   i=0
   while : ; do
         #echo DEBUG Doing check if rpm -qa process is ended $i
         if [ $i -gt $thetimeout ] ; then
            ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
            [ $? -eq 0 ] && { kill $theps ; echo Warning $theps killed ; } ;
            timeout_encountered=1
            break
         fi
         ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
         [ $? -eq 0 ] || { echo INFO $theps finished within time ; break ; } ;
         i=$(expr $i + 1)
         sleep 1
   done
   wait $theps
   status=$?
   if [ $timeout_encountered -ne 0 ] ; then
      printf "install_cmssw_osx() apt-get updated timed out\n$(cat  $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() apt-get update timed out" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
   #if [ $status -ne 0 ] ; then
   #   printf "install_cmssw_osx() rpmdb rebuild failed\n$(cat  $HOME/rpmdb_rebuild.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() rpmdb rebuild failed" $notifytowhom
   #   return 1
   #fi
   
   if [ $status -ne 0 ] ; then
      echo ERROR failed apt-get update
      printf "install_cmssw_osx() apt-get update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
      return 1
   fi

   grep -q -i "^error: " $HOME/apt_get_update.log
   if [ $? -eq 0 ] ; then
      echo ERROR failed apt-get update
      printf "install_cmssw_osx() apt-get update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
      return 1
   fi

   grep -q -i "^E: " $HOME/apt_get_update.log
   if [ $? -eq 0 ] ; then
      echo ERROR failed apt-get update
      printf "install_cmssw_osx() apt-get update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
      return 1
   fi

   if [ "x$cvmfs_server_yes" == "xno" ] ; then
      ls -al $HOME/slc*.lock 2>/dev/null 1>/dev/null
      if [ $? -eq 0 ] ; then
         echo Warning rsync may be in progress from the cvmfs server. Waiting for the next opportunity.
         printf "install_cmssw_osx() Warning rsync may be in progress from the cvmfs server. We will wait for the next opportunity for $cmssw_release ${SCRAM_ARCH} \n" | mail -s "[0] install_cmssw_osx() something is locked. Wait for the next opp." $notifytowhom
         return 1
      fi
      ( printf "install_cmssw_osx() locking installation for cmssw_release=$cmssw_release ${SCRAM_ARCH} \n" | mail -s "[0] install_cmssw_osx() LOCK installation" $notifytowhom ; cd ; touch ${SCRAM_ARCH}.lock ;  )
   fi

   echo DEBUG checking fakesystem
   rpm -qa --dbpath /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm | grep fakesystem
   if [ $(rpm -qa --dbpath /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm | grep -q fakesystem ; echo $? ) -ne 0 ] ; then
      fakesystems=$(apt-cache pkgnames | grep fakesystem)
      echo INFO installing fakes $fakesystems
      #printf "install_cmssw_osx() installing fakesystems\n" | mail -s "install_cmssw_osx() installing fakesystems" $notifytowhom
      apt-get --assume-yes -c=$apt_config install $fakesystems >& $HOME/apt_get_install_fakesystems.log &
      theps=$!
      timeout_encountered=0
      i=0
      while : ; do
         #echo DEBUG Doing check if rpm -qa process is ended $i
         if [ $i -gt $thetimeout ] ; then
            ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
            [ $? -eq 0 ] && { kill $theps ; echo Warning $theps killed ; } ;
            timeout_encountered=1
            break
         fi
         ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
         [ $? -eq 0 ] || { echo INFO $theps finished within time ; break ; } ;
         i=$(expr $i + 1)
         sleep 1
      done
      wait $theps
      status=$?
      if [ $timeout_encountered -ne 0 ] ; then
         printf "install_cmssw_osx() apt-get install fakesystem timed out\n$(cat   $HOME/apt_get_install_fakesystems.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() apt-get install fakesystem timed out" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         return 1
      fi
      [ $status -eq 0 ] || { echo fakesystems install failed ; printf "install_cmssw_osx() apt-get install fakesystem failed\n$(cat   $HOME/apt_get_install_fakesystems.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() apt-get install fakesystem failed" $notifytowhom ; cd ; cvmfs_server abort -f ; return 1 ; } ;
   fi
   #while : ; do  ps auxwww | grep shared | grep -v grep | grep -q cron_install_cmssw.sh ; [ $? -eq 0 ] && { echo INFO still running ; sleep 1 ; continue ; } ; ./download_cron_script.sh ; break ; done
#if [ ] ; then
#   echo INFO installing $cmssw_release ${SCRAM_ARCH} via apt-get --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$cmssw_release
#   apt-get --fix-broken --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$cmssw_release 2>&1 | tee $HOME/apt_get_install.log
#fi # if [ ] ; then

   #if [ ] ; then
   thetimeout=7200

   echo INFO installing $cmssw_release ${SCRAM_ARCH} via apt-get --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$cmssw_release
   #printf "install_cmssw_osx() apt-get install started\n" | mail -s "install_cmssw_osx() apt-get install started" $notifytowhom
   apt-get --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$cmssw_release >& $HOME/apt_get_install.log &
   theps=$!
   timeout_encountered=0
   i=0
   while : ; do
         #echo DEBUG Doing check if rpm -qa process is ended $i
         if [ $i -gt $thetimeout ] ; then
            ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
            [ $? -eq 0 ] && { kill $theps ; echo Warning $theps killed ; } ;
            timeout_encountered=1
            break
         fi
         ps auxwww | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
         [ $? -eq 0 ] || { echo INFO $theps finished within time ; break ; } ;
         i=$(expr $i + 1)
         sleep 1
   done
   wait $theps
   status=$?
   if [ $timeout_encountered -ne 0 ] ; then
      printf "install_cmssw_osx() apt-get install timed out\n$(cat  $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() apt-get install timed out" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
   
   #fi # if [ ] ; then

   grep -A 100 -B 100 "W: Bizarre Error - File size is not what the server reported" $HOME/apt_get_install.log | grep -q "E: Unable to fetch some archives"
   if [ $? -eq 0 ] ; then
      echo DEBUG we will try to install apt
      apt-get --assume-yes -c=$apt_config install external+apt+0.5.16 2>&1 | tee $HOME/apt_get_install_external+apt.log
      source $(ls -t ${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)
      status_init=$?
      # for cvmfs_server
      source $(ls -t ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
      ldd $(which curl)
      #echo INFO ldd $(which curl) status=$?
      ldd $(which curl) 2>&1 | grep OPENSSL | grep -q "not found"
      if [ $? -eq 0 ] ; then
         source $(ls -t ${SLC_SCRAM_ARCH}/external/openssl/*/etc/profile.d/init.sh | head -1)
      fi
      
      ldd $(which curl) 2>&1 | grep -q "not found"
      if [ $? -eq 0 ] ; then
         echo ERROR failed to set up curl env\nSome library may be missing $(ldd $(which curl))
         printf "install_cmssw()  set up curl env failed\nSome library may be missing\necho ldd $(which curl) result follows\n$(ldd $(which curl))\n" | mail -s "ERROR install_cmssw() set up curl env failed" $notifytowhom
         return 1
      fi

      # unfix NSS mess
      #THE_NSS_PATH=$(for p in $(echo $LD_LIBRARY_PATH | sed 's#:# #g') ; do echo $p | grep /cvmfs/cms.cern.ch/${SLC_SCRAM_ARCH}/external/nss/ ; done | sort -u)
      #export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed -e "s#$THE_NSS_PATH:##g" | sed -e "s#:$THE_NSS_PATH##g")
      # for curl in cvmfs_server
      #source $(ls -t ${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
      echo DEBUG status_init=$status_init which apt-get
      which apt-get 2>&1

      echo INFO executing apt-get --assume-yes update for $cmssw_release ${SCRAM_ARCH}
      apt-get --assume-yes -c=$apt_config update > $HOME/apt_get_update.log 2>&1 # 2>&1 | tee $HOME/apt_get_update.log
      if [ $? -ne 0 ] ; then
         echo ERROR failed apt-get update
         printf "install_cmssw_osx() 2 apt-get update failed for $cmssw_release ${SCRAM_ARCH}\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         #cvmfs_server abort -f
         return 1
      fi

      grep -q -i "^error: " $HOME/apt_get_update.log
      if [ $? -eq 0 ] ; then
         echo ERROR failed apt-get update
         printf "install_cmssw_osx() 2 apt-get update failed for $cmssw_release $SCRAM_ARCH\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         #cvmfs_server abort -f
         return 1
      fi

      grep -q -i "^E: " $HOME/apt_get_update.log
      if [ $? -eq 0 ] ; then
         echo ERROR failed apt-get update
         printf "install_cmssw_osx() 2 apt-get update failed for $cmssw_release $SCRAM_ARCH\n$(cat $HOME/apt_get_update.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         #cvmfs_server abort -f
         return 1
      fi

      echo INFO executing CMSSW install again
      apt-get --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$cmssw_release > $HOME/apt_get_install.log 2>&1 # 2>&1 | tee $HOME/apt_get_install.log
      status=$?
   fi

   grep -q -i "^error: " $HOME/apt_get_install.log
   if [ $? -eq 0 ] ; then
      printf "install_cmssw_osx() apt-get install failed for $cmssw_release $SCRAM_ARCH\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
      return 1
   fi

   grep -q -i "^E: " $HOME/apt_get_install.log
   if [ $? -eq 0 ] ; then
      printf "install_cmssw_osx() apt-get install failed for $cmssw_release $SCRAM_ARCH \n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
      return 1
   fi

   ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src 2>/dev/null 1>/dev/null
   if [ $? -ne 0 ] ; then
      echo ERROR strangely $cmssw_release $SCRAM_ARCH is not installed
      printf "install_cmssw_osx() apt-get install failed for $cmssw_release $SCRAM_ARCH\nCheck ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src\n$(ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/${thedir}/$cmssw_release/src)\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "install_cmssw_osx() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
      return 1
   fi

   if [ $status -eq 0 ] ; then
      printf "install_cmssw_osx() $cmssw_release $SCRAM_ARCH installed from $(/bin/hostname -f)\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "[1] install_cmssw_osx() $cmssw_release INSTALLED" $notifytowhom
   else
      echo ERROR failed apt-get install
      printf "install_cmssw_osx() apt-get install failed for $cmssw_release $SCRAM_ARCH\n$(cat $HOME/apt_get_install.log | sed 's#%#%%#g')\n" | mail -s "[1] install_cmssw_osx() failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      #cvmfs_server abort -f
      return 1
   fi
   # 1.3.4 update /cvmfs/cms.cern.ch/releases.map
   cp $releases_map_local /cvmfs/cms.cern.ch/

   echo INFO cmssw installed: $cmssw_release $SCRAM_ARCH
   return 0
}

function cron_install_cmssw_osx() {
  # 1 get all the osx archs
  for arch in $(collect_osx_rpms_page) ; do
   if [ -f "$(ls -t $VO_CMS_SW_DIR/${arch}/external/apt/*/etc/profile.d/init.sh | head -1)" ] ; then
      echo INFO ${arch} seems to be bootstrapped.
   else
      /usr/bin/wget -q -O $HOME/${arch}.tar.gz --connect-timeout=360 --read-timeout=360 http://oo.ihepa.ufl.edu:8080/cmssoft/${arch}.tar.gz 2>/dev/null
      if [ $? -ne 0 ] ; then
         printf "$(basename $0) http://oo.ihepa.ufl.edu:8080/cmssoft/${arch}.tar.gz needed\n" | mail -s "$(basename $0) bootstrap needed for $arch" $notifytowhom
         continue
      fi
      currdir_1=$(pwd)
      cd
      cvmfs_server transaction
      status=$?
      what="$(basename $0) $arch tarball bootstrap"
      cvmfs_server_transaction_check $status $what
      if [ $? -eq 0 ] ; then
         echo INFO transaction OK for $what
         cd $VO_CMS_SW_DIR
         tar xzvf $HOME/${arch}.tar.gz
         publish_cmssw_cvmfs ${0}+${arch}+bootstrap
         cd $currdir_1
      else
         printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom
         cd $currdir_1
         continue
      fi
   fi
   echo DEBUG cmssw in $arch
   for cmssw in $(list_osx_cmssws $arch) ; do echo $cmssw ; done
   echo DEBUG end of cmssw in $arch
   for cmssw in $(list_osx_cmssws $arch) ; do
      grep -q "$cmssw $arch " $updated_list
      if [ $? -eq 0 ] ; then
         echo INFO $cmssw $arch in $updated_list
         continue
      fi
      printf "$(basename $0) Installing $cmssw $arch\n"
      printf "$(basename $0) Installing $cmssw $arch\n" | mail -s "$(basename $0) Started $cmssw $arch installation" $notifytowhom
      install_cmssw_osx $cmssw $arch
      if [ $? -eq 0 ] ; then
         echo INFO adding $arch to cvmfsdirtab
         add_nested_entry_to_cvmfsdirtab ${arch}
         [ $? -eq 0 ] || printf "$(basename $0) ERROR: Failed to add the entry /${arch}/cms/$cmssw to $VO_CMS_SW_DIR/.cvmfsdirtab\n" | mail -s "$(basename $0) ERROR: FAILED to add the nested CVMFS dir entry for $arch" $notifytowhom
         echo INFO publish the installed $cmssw $arch on cvmfs if necessary
         publish_cmssw_cvmfs ${0}+${cmssw}+${arch}
         if [ $? -eq 0 ] ; then
            echo INFO cmssw=$cmssw arch=$arch published
            grep -q "$cmssw $arch" $db
            [ $? -eq 0 ] || { echo INFO adding cmssw=$cmssw arch=$arch to $db ; echo "$cmssw $arch" >> $db ; } ;
            #mock_up_publish_cmssw_cvmfs
            grep -q "$cmssw $arch " $updated_list
            if [ $? -eq 0 ] ; then
              echo Warning strange $cmssw $arch already in the updates
              printf "$(basename $0): Warning strange $cmssw $arch already in $updated_list\n" | mail -s "$(basename $0): Warning $cmssw $arch already in $updated_list" $notifytowhom
            else
              currdir_1=$(pwd)
              cd
              cvmfs_server transaction
              status=$?
              what="adding_$cmssw_$arch_to_updated_list"
              cvmfs_server_transaction_check $status $what
              if [ $? -eq 0 ] ; then
                 echo INFO transaction OK for $what
              fi
              echo INFO adding $cmssw $arch to $updated_list
              echo $cmssw $arch $(/bin/date +%s) $(/bin/date -u) >> $updated_list
              printf "$(basename $0): $cmssw $arch added to $updated_list \n$(cat $updated_list)\n" | mail -s "$(basename $0): INFO $cmssw $arch added to $updated_list" $notifytowhom
              echo INFO publishing $updated_list
              publish_cmssw_cvmfs ${0}+${cmssw}+${arch}+$updated_list
              cd $currdir_1
            fi
         fi
      else
         echo "          ERROR $cmssw $arch install failed"
         continue
      fi
   done
  done
  return 0
}

function bootstrap_arch_tarball () {
  arch=$1
  if [ -f "$(ls -t $VO_CMS_SW_DIR/${arch}/external/apt/*/etc/profile.d/init.sh | head -1)" ] ; then
      echo INFO ${arch} seems to be bootstrapped.
  else
      /usr/bin/wget -q -O $HOME/${arch}.tar.gz --connect-timeout=360 --read-timeout=360 http://oo.ihepa.ufl.edu:8080/cmssoft/${arch}.tar.gz 2>/dev/null
      if [ $? -ne 0 ] ; then
         printf "FAILED: bootstrap_arch_tarball $arch\nfrom http://oo.ihepa.ufl.edu:8080/cmssoft/${arch}.tar.gz\n" | mail -s "FAILED: bootstrap_arch_tarball $arch" $notifytowhom
         return 1
      fi
      currdir_1=$(pwd)
      cd
      cvmfs_server transaction
      status=$?
      what="bootstrap_arch_tarball $arch"
      cvmfs_server_transaction_check $status $what
      if [ $? -eq 0 ] ; then
         echo INFO transaction OK for $what
         cd $VO_CMS_SW_DIR
         tar xzvf $HOME/${arch}.tar.gz 2>&1 | tee bootstrap_${arch}.log
         publish_cmssw_cvmfs bootstrap_arch_tarball+${arch}
         cd $currdir_1
      else
         printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ; cd $currdir_1
         return 1
      fi
  fi
  return 0
}

# 0.6.4
# 15JUL2013 we should add split and make new installation dir nested
function add_nested_entry_to_cvmfsdirtab () {
   if [ $# -lt 1 ] ; then
      echo ERROR add_nested_entry_to_cvmfsdirtab arch
      return 1
   fi
   thearch=$1
   for thecmssw in cmssw cmssw-patch ; do
      n_a_cmssw=$(ls  $VO_CMS_SW_DIR/${thearch}/cms/$thecmssw | wc -l)
      if [ $n_a_cmssw -gt 0 ] ; then
         #grep -q /${thearch}/cms/$thecmssw $VO_CMS_SW_DIR/.cvmfsdirtab
         echo $thearch  | grep -e 'fc\|sl'\* | grep -q gcc\*
         if [ $? -eq 0 ] ; then
            echo INFO the entry /${thearch}/cms/$thecmssw is already in $VO_CMS_SW_DIR/.cvmfsdirtab
         else
            thesl=$(echo $thearch | cut -c1,2)
            thecompil=$(echo $thearch | cut -d_ -f3 | cut -c1-3)
            #echo INFO adding the entry /${thearch}/cms/$thecmssw to $VO_CMS_SW_DIR/.cvmfsdirtab
            #echo /${thearch}/cms/$thecmssw >> $VO_CMS_SW_DIR/.cvmfsdirtab
            echo INFO adding the entry /${thesl}\*${thecompil}\*/cms/${thecmssw}/\* to $VO_CMS_SW_DIR/.cvmfsdirtab
            echo /${thesl}\*${thecompil}\*/cms/${thecmssw}/\* >> $VO_CMS_SW_DIR/.cvmfsdirtab
            printf "add_nested_entry_to_cvmfsdirtab INFO: added the entry /${thearch}/cms/$thecmssw to $VO_CMS_SW_DIR/.cvmfsdirtab\n" | mail -s "add_nested_entry_to_cvmfsdirtab INFO: Nested CVMFS dir entry added for $thearch" $notifytowhom
         fi
      fi
   done
   
   return 0
}

function mock_up_publish_cmssw_cvmfs () {
   echo INFO "publish_cmssw_cvmfs()"
   return 0
}

function publish_cmssw_cvmfs () {
   for_what=$1
   [ "x$for_what" == "x" ] && for_what=$(date +%s)
   echo INFO publishing the installation in the cvmfs
   currdir=$(pwd)
   cd
   publish_release=release-${for_what}
   #cvmfs_server lstags | grep -q release-${for_what}
   cvmfs_server tag | grep -q release-${for_what}
   if [ $? -eq 0 ] ; then
      publish_release=release-${for_what}+$(date +%s)
   fi
   #time cvmfs_server publish -r ${publish_release} 2>&1 | tee $HOME/cvmfs_server+publish+cmssw+install.log
   #export CVMFS_SERVER_DEBUG=3 
   time cvmfs_server publish > $HOME/logs/cvmfs_server+publish+cmssw+install.log 2>&1 # 2>&1 | tee $HOME/cvmfs_server+publish+cmssw+install.log
   status=$?
   unset CVMFS_SERVER_DEBUG
   cd $currdir
   if [ $status -eq 0 ] ; then
      printf "publish_cmssw_cvmfs () cvmfs_server_publish OK for $for_what \n$(cat $HOME/logs/cvmfs_server+publish+cmssw+install.log | sed 's#%#%%#g')\n" | mail -s "publish_cmssw_cvmfs () cvmfs_server publish for cmssw install OK" $notifytowhom
   else
      echo ERROR failed cvmfs_server publish
      printf "publish_cmssw_cvmfs () cvmfs_server publish failed for $for_what\n$(cat $HOME/logs/cvmfs_server+publish+cmssw+install.log | sed 's#%#%%#g')\nCheck ldd which curl\n$(ldd $(which curl))\n" | mail -s "publish_cmssw_cvmfs () failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
   #echo INFO cmssw installation is published from the cvmfs server
   #if [ -f $HOME/cic_send_log.sh ] ; then
   #   echo INFO sending $updated_list to the Central OPS
   #   $HOME/cic_send_log.sh
#   echo INFO checking http://oo.ihepa.ufl.edu:8080/cmssoft/aptinstall/logs/cic_${cvmfs_server_name}.cern.ch.log
   #fi
   return 0
}

function install_cms_common () {
   status=1   
   
   # use cmspkg instead of apt-get
   which cmspkg 2>/dev/null 1>/dev/null
   [ $? -eq 0 ] || { export PATH=$PATH:/cvmfs/cms.cern.ch/common ; } ;
   for cms_common_v_a in $cms_common_version_archs ; do
      cms_common_v=$(echo $cms_common_v_a | cut -d+ -f1)
      cms_common_a=$(echo $cms_common_v_a | cut -d+ -f2)
      if [ "x$cvmfs_server_yes" == "xno" ] ; then
         echo "$cms_common_a" | grep -q "$which_slc"
         if [ $? -ne 0 ] ; then
            echo Warning this machine cannot handle cms_common for arch=$cms_common_a We pass this arch.
            continue
         fi
      else
        if [ "x$which_slc" == "xslc5" ] ; then
           echo "$cms_common_a" | grep -q "$which_slc"
           if [ $? -ne 0 ] ; then
              echo Warning this machine cannot handle cms_common for arch=$cms_common_a We pass this arch.
              continue
           fi

           echo "$cms_common_a" | grep -q "$which_slc"
           [ $? -eq 0 ] || { echo Warning cms_common_a=$cms_common_a vs which_slc=$which_slc ; continue ; } ;
        fi
      fi

      grep -q "CMSSW_cms_common_1.0+${cms_common_v} $cms_common_a" $updated_list
      if [ $? -eq 0 ] ; then
         echo INFO cms_common_1.0 $cms_common_v $cms_common_a in the $updated_list
         continue
      else
         if [ "x$cvmfs_server_yes" == "xno" ] ; then
           ls -al $HOME/slc*.lock 2>/dev/null 1>/dev/null
           if [ $? -eq 0 ] ; then
              echo Warning rsync may be in progress from the cvmfs server
              printf "install_cms_common() Warning rsync may be in progress from the cvmfs server. We will wait for the next opportunity for $cms_common_v $cms_common_a\n" | mail -s "[0] install_cms_common() something is locked. Wait for the next opp." $notifytowhom
              continue
           fi
           ( printf "install_cms_common() locking installation for  $cms_common_v $cms_common_a\n" | mail -s "[0] install_cms_common() LOCK installation" $notifytowhom ; cd ; touch ${cms_common_a}.lock ; )
         fi
         #echo INFO executing cic_install_cms_common $cms_common_a $cms_common_v
         #cic_install_cms_common $cms_common_a $cms_common_v > $HOME/cic_install_cms_common.log 2>&1
         echo INFO executing cmspkg_install_cms_common $cms_common_a $cms_common_v
         cmspkg_install_cms_common $cms_common_a $cms_common_v > $HOME/logs/cmspkg_install_cms_common.log 2>&1
         if [ $? -eq 0 ] ; then
            currdir=$(pwd)
            cd
            cvmfs_server transaction
            status=$?
            what="add_cms_common_to_updated_list"
            cvmfs_server_transaction_check $status $what
            if [ $? -eq 0 ] ; then
               echo INFO transaction for $what is OK
            fi
            echo "CMSSW_cms_common_1.0+${cms_common_v} $cms_common_a $(/bin/date +%s) $(/bin/date -u)" >> $updated_list
            #cvmfs_server abort -f
            time cvmfs_server publish > $HOME/logs/cvmfs_server+publish.log 2>&1
            status=$?
            cd $currdir
            if [ $status -eq 0 ] ; then
               printf "install_cms_common $(/bin/hostname -f) cms_common_1.0 $cms_common_v $cms_common_a installed\nInstallation Log:\n$(cat $HOME/logs/cmspkg_install_cms_common.log | sed 's#%#%%#g')\n" | /bin/mail -s "published and install_cms_common cms_common_1.0 $cms_common_v $cms_common_a installed" $notifytowhom
               status=0
               if [ "x$cvmfs_server_yes" == "xno" ] ; then # if [ ! -x /usr/bin/cvmfs_server ] ; then
                 grep -q CMSSW_cms_common_1.0+${cms_common_v} "$HOME/${cms_common_a}.rsync.ready"
                 [ $? -eq 0 ] || echo CMSSW_cms_common_1.0+${cms_common_v} >> "$HOME/${cms_common_a}.rsync.ready"
                 echo INFO no cvmfs server. will tell the main script not to publish
                 status=1
               fi
            else
               printf "install_cms_common $(/bin/hostname -f) cms_common_1.0 $cms_common_v $cms_common_a installed\nInstallation Log:\n$(cat $HOME/logs/cmspkg_install_cms_common.log | sed 's#%#%%#g')\n$(cat $HOME/logs/cvmfs_server+publish.log)\n" | /bin/mail -s "ERROR publish failed:install_cms_common cms_common_1.0 $cms_common_v $cms_common_a installed" $notifytowhom
                
            fi # if [ $status -eq 0 ] ; then

         fi
      fi
   done
   return $status
}

function cic_install_cms_common () { # not used any more
  if [ $# -lt 2 ] ; then
     echo ERROR cic_install_cms_common SCRAM_ARCH version
     return 1
  fi
  scram_arch=$1
  version=$2
  echo INFO sourcing cmsset_default.sh
  source $VO_CMS_SW_DIR/cmsset_default.sh 2>&1
  echo INFO setting up apt
  #source $VO_CMS_SW_DIR/${scram_arch}/external/apt/*/etc/profile.d/init.sh 2>&1
  source $(ls -t $VO_CMS_SW_DIR/${scram_arch}/external/apt/*/etc/profile.d/init.sh | head -1) 2>&1
  source $(ls -t $VO_CMS_SW_DIR/${scram_arch}/external/curl/*/etc/profile.d/init.sh | head -1)

  echo INFO checking ldd $(which curl)
  ldd $(which curl)
  ldd $(which curl) 2>&1 | grep OPENSSL | grep -q "not found"
  if [ $? -eq 0 ] ; then
     source $(ls -t $VO_CMS_SW_DIR/${scram_arch}/external/openssl/*/etc/profile.d/init.sh | head -1)
  fi

  echo INFO which apt-get
  which apt-get 2>&1
  echo INFO checking cms-common before installing it
  rpm -qa | grep cms-common | grep -q ${version}
  if [ $? -eq 0 ] ; then
     grep -q "$version" /cvmfs/cms.cern.ch/etc/cms-common/revision
     if [ $? -eq 0 ] ; then
        echo INFO cms-common+1.0 version=$version is already installed
        return 0
     fi
  fi

  rpm -qa | grep cms-common
  printf "cic_install_cms_common () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom

  echo INFO starting server transaction
  echo which apt-get
  which apt-get

  echo which curl
  which curl

  echo ldd $(which curl) #"curl $(get_follow_http_redirects_flag)" "$url"
  ldd $(which curl)

  echo which openssl
  which openssl

  echo which cvmfs_server
  which cvmfs_server

  
  currdir=$(pwd)
  cd
  cvmfs_server transaction
  status=$?
  what="cic_install_cms_common ()"
  cvmfs_server_transaction_check $status $what
  if [ $? -eq 0 ] ; then
     echo INFO transaction OK for $what
  else
     echo Warning transaction again
     sh -x cvmfs_server transaction
     echo Warning abort transaction
     cvmfs_server abort -f
     printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom
     cd $currdir
     return 1
  fi

  echo INFO updating the apt repo
  apt-get update 2>&1

  echo INFO installing cms-common+1.0 version $version
  apt-get install '--assume-yes' cms+cms-common+1.0

  echo INFO checking cms-common after installing
  rpm -qa | grep cms-common | grep -q ${version}
  if [ $? -eq 0 ] ; then
     echo INFO cms-common version=$version is installed
     rpm -qa | grep cms-common
     status=0
     grep -q "$version" /cvmfs/cms.cern.ch/etc/cms-common/revision
     if [ $? -eq 0 ] ; then
        echo INFO $version found
        time cvmfs_server publish > $HOME/logs/cvmfs_server+publish.log 2>&1
        status=$?
        cd $currdir
        return $status
     else
        echo INFO $version not found
        echo INFO executing apt-get reinstall cms+cms-common+1.0
        apt-get '--assume-yes' reinstall cms+cms-common+1.0
        status=$?
        if [ $status -eq 0 ] ; then
           grep -q "$version" /cvmfs/cms.cern.ch/etc/cms-common/revision
           status=$?
           if [ $status -eq 0 ] ; then
              time cvmfs_server publish > $HOME/logs/cvmfs_server+publish.log 2>&1
              status=$?
              cd $currdir
              return $status
           else
              echo ERROR $version still not found after apt-get '--assume-yes' reinstall cms+cms-common+1.0
              cvmfs_server abort -f
              cd $currdir
              return 1
           fi
        else
           echo ERROR FAILED: apt-get '--assume-yes' reinstall cms+cms-common+1.0
           cvmfs_server abort -f
           cd $currdir
           return 1
        fi
     fi

     #cd $currdir
     #time cvmfs_server publish > $HOME/logs/cvmfs_server+publish.log 2>&1
     #return $?
  else
     echo ERROR cms-common version=$version installation failed
     rpm -qa | grep cms-common
     cvmfs_server abort -f
     cd $currdir
     return 1
  fi

}

function cmspkg_install_cms_common () {
  if [ $# -lt 2 ] ; then
     echo ERROR cmspkg_install_cms_common SCRAM_ARCH version
     return 1
  fi
  scram_arch=$1
  version=$2
  CMSPKG="$VO_CMS_SW_DIR/common/cmspkg -a $SCRAM_ARCH"

  # because of cmspkg, we should not need to set up apt
if [ ] ; then
  echo INFO sourcing cmsset_default.sh
  source $VO_CMS_SW_DIR/cmsset_default.sh 2>&1

  echo INFO setting up apt
  #source $VO_CMS_SW_DIR/${scram_arch}/external/apt/*/etc/profile.d/init.sh 2>&1
  source $(ls -t $VO_CMS_SW_DIR/${scram_arch}/external/apt/*/etc/profile.d/init.sh | head -1) 2>&1
  source $(ls -t $VO_CMS_SW_DIR/${scram_arch}/external/curl/*/etc/profile.d/init.sh | head -1)

  echo INFO checking ldd $(which curl)
  ldd $(which curl)
  ldd $(which curl) 2>&1 | grep OPENSSL | grep -q "not found"
  if [ $? -eq 0 ] ; then
     source $(ls -t $VO_CMS_SW_DIR/${scram_arch}/external/openssl/*/etc/profile.d/init.sh | head -1)
  fi

  echo INFO which apt-get
  which apt-get 2>&1
fi # if [ ] ; then

  echo INFO checking cms-common before installing it
  rpm -qa | grep cms-common | grep -q ${version}
  if [ $? -eq 0 ] ; then
     grep -q "$version" /cvmfs/cms.cern.ch/etc/cms-common/revision
     if [ $? -eq 0 ] ; then
        echo INFO cms-common+1.0 version=$version is already installed
        return 0
     fi
  fi

  rpm -qa | grep cms-common
  printf "cmspkg_install_cms_common () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom

  echo INFO starting server transaction
  #echo which apt-get
  #which apt-get

  #echo which curl
  #which curl

  #echo ldd $(which curl) #"curl $(get_follow_http_redirects_flag)" "$url"
  #ldd $(which curl)

  #echo which openssl
  #which openssl

  #echo which cvmfs_server
  #which cvmfs_server

  
  currdir=$(pwd)
  cd
  cvmfs_server transaction
  status=$?
  what="cmspkg_install_cms_common ()"
  cvmfs_server_transaction_check $status $what
  if [ $? -eq 0 ] ; then
     echo INFO transaction OK for $what
  else
     echo Warning transaction again
     sh -x cvmfs_server transaction
     echo Warning abort transaction
     cvmfs_server abort -f
     printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom
     cd $currdir
     return 1
  fi

  $CMSPKG -y upgrade

  echo INFO updating the repo
  $CMSPKG update 2>&1 # apt-get update 2>&1

  echo INFO installing cms-common+1.0 version $version
  $CMSPKG -f install cms+cms-common+1.0 #apt-get install '--assume-yes' cms+cms-common+1.0

  echo INFO checking cms-common after installing
  rpm -qa | grep cms-common | grep -q ${version}
  if [ $? -eq 0 ] ; then
     echo INFO cms-common version=$version is installed
     rpm -qa | grep cms-common
     status=0
     grep -q "$version" /cvmfs/cms.cern.ch/etc/cms-common/revision
     if [ $? -eq 0 ] ; then
        echo INFO $version found
        time cvmfs_server publish > $HOME/logs/cvmfs_server+publish.log 2>&1
        status=$?
        cd $currdir
        return $status
     else
        echo INFO $version not found
        echo INFO reinstalling it # executing apt-get reinstall cms+cms-common+1.0
        #apt-get '--assume-yes' reinstall cms+cms-common+1.0
        ${CMSPKG} --reinstall -y cms+cms-common+1.0
        status=$?
        if [ $status -eq 0 ] ; then
           grep -q "$version" /cvmfs/cms.cern.ch/etc/cms-common/revision
           status=$?
           if [ $status -eq 0 ] ; then
              time cvmfs_server publish > $HOME/logs/cvmfs_server+publish.log 2>&1
              status=$?
              cd $currdir
              return $status
           else
              echo ERROR $version still not found after reinstalling it # apt-get '--assume-yes' reinstall cms+cms-common+1.0
              printf "cmspkg_install_cms_common: cms-common reinstall  failed\n" | mail -s "ERROR: cms-common resintall failed" $notifytowhom
              cvmfs_server abort -f
              cd $currdir
              return 1
           fi
        else
           echo ERROR FAILED: reinstall failed # apt-get '--assume-yes' reinstall cms+cms-common+1.0
           cvmfs_server abort -f
           cd $currdir
           return 1
        fi
     fi

     #cd $currdir
     #time cvmfs_server publish > $HOME/logs/cvmfs_server+publish.log 2>&1
     #return $?
  else
     echo ERROR cms-common version=$version installation failed
     rpm -qa | grep cms-common
     cvmfs_server abort -f
     cd $currdir
     return 1
  fi

}

# not used any more
function install_crab2 () {
  echo DEBUG VO_CMS_SW_DIR $VO_CMS_SW_DIR
  echo DEBUG crab_tarball_top $crab_tarball_top

  if [ ! -d $VO_CMS_SW_DIR/crab ] ; then
     printf "install_crab2 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
     currdir=$(pwd)
     cd
     cvmfs_server transaction
     status=$?
     what="install_crab2 ()"
     cvmfs_server_transaction_check $status $what
     if [ $? -eq 0 ] ; then
      echo INFO transaction OK for $what
     else
      printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
      cd $currdir
      return 1
     fi
     mkdir -p $VO_CMS_SW_DIR/crab
     ( cd ; cvmfs_server abort -f ; ) ;
     cd $currdir
     #cvmfs_server abort -f
  fi
  crab_tarballs=$(wget -O- ${crab_tarball_top} 2>/dev/null | grep tgz | cut -d\> -f6 | cut -d\" -f2 | grep ^CRAB_2_)  
  CRABS=$(for crab in $crab_tarballs ; do echo $crab ; done | sed "s#.tgz##g")
  for crab in $CRABS ; do
      echo INFO crab $crab
      [ -f $VO_CMS_SW_DIR/crab/${crab}/crab.sh ] && { echo INFO $crab already installed ; continue ; } ;
      echo INFO "[0]" installing $crab
      ( cd $HOME
        wget -q -O $HOME/${crab}.tgz ${crab_tarball_top}/${crab}.tgz
        [ $? -eq 0 ] || { echo DEBUG download failed for ${crab_tarball_top}/${crab}.tgz ; return 1 ; } ;
        #cd $VO_CMS_SW_DIR/crab
        printf "install_crab2 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
        cvmfs_server transaction
        status=$?
        what="install_crab2 ()"
        cvmfs_server_transaction_check $status $what
        if [ $? -eq 0 ] ; then
           echo INFO transaction OK for $what
        else
           printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
           return 1
        fi
        ( cd $VO_CMS_SW_DIR/crab ; tar xzvf $HOME/${crab}.tgz ; exit $? ; ) ;
        [ $? -eq 0 ] || { echo DEBUG untar failed for $HOME/${crab}.tgz under $VO_CMS_SW_DIR/crab ;                           ( cd ; cvmfs_server abort -f ; ) ; return 1 ; } ;
        ( cd $VO_CMS_SW_DIR/crab/${crab} ; ./configure ; exit $? ; ) ;
        [ $? -eq 0 ] || { echo DEBUG crab configure failed under $VO_CMS_SW_DIR/crab/${crab} ; ( cd ; cvmfs_server abort -f ; ) ; return 1 ; } ;
        echo ${crab} | grep -q _pre        
        if [ $? -eq 0 ] ; then
           echo INFO it is a pre release. Creating a soft-link
           rm -f $VO_CMS_SW_DIR/crab/crab_pre.{c,}sh
           status=$?
           echo DEBUG 1 status $status
           ln -s $VO_CMS_SW_DIR/crab/${crab}/crab.sh $VO_CMS_SW_DIR/crab/crab_pre.sh
           status=$(expr $status + $?)
           echo DEBUG 2 status $status
           ln -s $VO_CMS_SW_DIR/crab/${crab}/crab.csh $VO_CMS_SW_DIR/crab/crab_pre.csh
           status=$(expr $status + $?)
           echo DEBUG 3 status $status
           #[ $status -eq 0 ] || cvmfs_server abort -f
           return $status           
        else
           echo INFO it is a production release. Creating a soft-link
           rm -f $VO_CMS_SW_DIR/crab/crab.{c,}sh
           status=$?
           echo DEBUG 1 status $status
           ln -s $VO_CMS_SW_DIR/crab/${crab}/crab.sh $VO_CMS_SW_DIR/crab/crab.sh
           status=$(expr $status + $?)
           echo DEBUG 2 status $status
           ln -s $VO_CMS_SW_DIR/crab/${crab}/crab.csh $VO_CMS_SW_DIR/crab/crab.csh
           status=$(expr $status + $?)
           echo DEBUG 3 status $status
           #[ $status -eq 0 ] || cvmfs_server abort -f
           return $status           
        fi
        return 0
      )
      [ $? -eq 0 ] || { ( cd ; cvmfs_server abort -f ; ) ; return 1 ; } ;
      grep -q "$crab " $updated_list
      if [ $? -eq 0 ] ; then
        echo Warning "[1]" $crab is already in the $updated_list
      else
        echo INFO "[1]" adding $crab noarch to $updated_list
        echo $crab noarch $(/bin/date +%s) $(/bin/date -u) >> $updated_list
      fi
      echo INFO "[2]" adding nested catalog
      if [ -d $VO_CMS_SW_DIR/crab/$crab ] ; then
         ls -al $VO_CMS_SW_DIR/crab/$crab/.cvmfscatalog 2>/dev/null 1>/dev/null ;
         if [ $? -eq 0 ] ; then
            echo INFO "[3]" $VO_CMS_SW_DIR/crab/$crab/.cvmfscatalog exists
         else
            echo INFO "[3]" creating $VO_CMS_SW_DIR/crab/$crab/.cvmfscatalog
            touch $VO_CMS_SW_DIR/crab/$crab/.cvmfscatalog
         fi
      fi

      echo INFO "[4]" publishing cvmfs
      publish_cmssw_cvmfs install_crab2

      printf "$(basename $0): $crab installed successfully on $VO_CMS_SW_DIR/crab/${crab}; \n" | mail -s "[4] $(basename $0) $crab Installed " $notifytowhom

  done

  soft_link_update_needed=no
  random_string=XXYYZZ8907
  for ocrab in new old ; do
     ocrab_release=${random_string}$(wget -q -O- ${crab_tarball_top}/crab_${ocrab}.sh | grep "^export CRABDIR=" | sed 's#/# #g' | awk '{print $NF}')
     #echo DEBUG ocrab=$ocrab ocrab_release=$ocrab_release
     crab2_release=$(echo ${ocrab_release} | sed "s#$random_string##")
     ls -al /cvmfs/cms.cern.ch/crab/crab_${ocrab}.sh 2>&1 | grep -q "$crab2_release"
     if [ $? -eq 0 ] ; then
        echo INFO /cvmfs/cms.cern.ch/crab/crab_${ocrab}.sh link is correct
     else
        printf "install_crab2 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
        currdir=$(pwd)
        cd
        cvmfs_server transaction
        status=$?
        what="install_crab2 ()"
        cvmfs_server_transaction_check $status $what
        if [ $? -eq 0 ] ; then
           echo INFO transaction OK for $what
        else
           printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
           cd $currdir
           return 1
        fi
        cd $currdir
        newlink=/cvmfs/cms.cern.ch/crab/${crab2_release}/crab.sh
        echo INFO linking /cvmfs/cms.cern.ch/crab/crab_${ocrab}.sh to $newlink
        rm -f /cvmfs/cms.cern.ch/crab/crab_${ocrab}.sh
        ( cd /cvmfs/cms.cern.ch/crab ; ln -s $newlink crab_${ocrab}.sh ; )
        ls -al /cvmfs/cms.cern.ch/crab/crab_${ocrab}.sh

        newlink=/cvmfs/cms.cern.ch/crab/${crab2_release}/crab.csh
        rm -f /cvmfs/cms.cern.ch/crab/crab_${ocrab}.csh
        ( cd /cvmfs/cms.cern.ch/crab ; ln -s $newlink crab_${ocrab}.csh ; )
        ls -al /cvmfs/cms.cern.ch/crab/crab_${ocrab}.csh  
        soft_link_update_needed=yes
        publish_cmssw_cvmfs install_crab2+other+setup
     fi
  done
  #if [ "$soft_link_update_needed" == "yes" ] ; then
  #    echo INFO "[5]" publishing cvmfs
  #    publish_cmssw_cvmfs install_crab2+other+setup
  #fi
  return 0
}

function install_crab3 () {
  export crab3repos="comp.pre"
  releases="3.2.0pre5 3.2.0pre5-comp 3.2.0pre16 3.2.0pre16-comp 3.3.0.pre3 3.3.0.pre3-comp"
  for release in $releases ; do
     grep -q "crabclient $release " $updated_list
     if [ $? -eq 0 ] ; then
        echo Warning crabclient $release installed according to $updated_list
        #return 0
     else
        printf "install_crab3 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
        currdir=$(pwd)
        cd
        cvmfs_server transaction
        status=$?
        what="install_crab3 ()"
        cvmfs_server_transaction_check $status $what
        if [ $? -eq 0 ] ; then
           echo INFO transaction OK for $what
        else
           printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
           cd $currdir
           return 1
        fi
        cd $currdir
        echo INFO adding crabclient $release to $updated_list
        echo crabclient $release $(/bin/date +%s) $(/bin/date -u) >> $updated_list
        ( cd ; cvmfs_server abort -f ; ) ; #cvmfs_server abort -f
     fi
  done

  for crab3repo in $crab3repos ; do
     export crab3_REPO=$crab3repo
     export crab3_SCRAM_ARCH=slc5_amd64_gcc461
     crab3_RPMS=http://cmsrep.cern.ch/cmssw/${crab3_REPO}/RPMS/${crab3_SCRAM_ARCH}/
     echo INFO checking ${crab3_RPMS}

     crab3s=$(wget -O- $crab3_RPMS 2>/dev/null | grep cms+crabclient+ | cut -d\> -f7 | cut -d\< -f1 | sed 's#slc# slc#g' | sed 's#cms+crabclient+# #g' | sed 's#-1-1.# #g' | sed 's#.rpm##g' | awk '{print $1}')
     currdir=$(pwd)
     for release in $crab3s ; do
        echo "$release" | grep -q pre
        [ $? -eq 0 ] && { echo INFO skipping pre release per Marco\'s request ; continue ; } ;
        grep -q "crabclient $release " $updated_list
        if [ $? -eq 0 ] ; then
           echo Warning crabclient $release installed according to $updated_list
           continue
        fi
        printf "install_crab3 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
        #currdir=$(pwd)
        cd
        cvmfs_server transaction
        status=$?
        what="install_crab3 ()"
        cvmfs_server_transaction_check $status $what
        if [ $? -eq 0 ] ; then
           echo INFO transaction OK for $what
        else
           printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
           cd $currdir
           return 1
        fi
        echo INFO installing $release under $VO_CMS_SW_DIR : install_crab3.sh $VO_CMS_SW_DIR $release ${crab3_REPO}
        $HOME/install_crab3.sh $VO_CMS_SW_DIR $release ${crab3_REPO} > $HOME/logs/install_crab3.${release}.log 2>&1
        status=$?
        printf "New CRAB3 Client Installed\n$(cat $HOME/logs/install_crab3.${release}.log | sed 's#%#%%#g')\n" | mail -s "INFO: New CRAB3 Client Installed" $notifytowhom
        if [ $status -eq 0 ] ; then
           grep -q "crabclient $release " $updated_list
           if [ $? -eq 0 ] ; then
              echo Warning crabclient $release installed
           else
              printf "install_crab3 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
              cvmfs_server transaction
              status=$?
              what="install_crab3 ()"
              cvmfs_server_transaction_check $status $what
              if [ $? -eq 0 ] ; then
                 echo INFO transaction OK for $what
              else
                 printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
                 cd $currdir
                 return 1
              fi
              echo INFO adding crabclient $release to $updated_list
              echo crabclient $release $(/bin/date +%s) $(/bin/date -u) >> $updated_list
              currdir=$(pwd)
              cd
              time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish.log
              cd $currdir
              printf "install_crab3 () published  \n$(cat $HOME/logs/cvmfs_server+publish.log | sed 's#%#%%#g')\n" | mail -s "cvmfs_server publish Done" $notifytowhom
           fi
        fi
     done
  done

  return 0
}

function install_slc6_crab3 () {
  #export crab3_REPO=$crab3repos 
  export crab3_REPO="comp.pre"
  export crab3_SCRAM_ARCH=slc6_amd64_gcc481
  
  releases="3.2.0pre16 3.3.0.pre3 3.3.0.rc1 3.3.1.pre2 3.3.4 3.3.4-comp 3.3.4.rc3 3.3.5 3.3.6.rc4 3.3.7.patch1 3.3.7.patch2 3.3.7.rc4 3.3.7.rc6 3.3.7.rc7 3.3.8.rc1" # 3.3.8 3.3.8.rc1 3.3.8.rc5"
  for release in $releases ; do
     grep -q "crabclient ${release} ${crab3_SCRAM_ARCH} " $updated_list
     if [ $? -eq 0 ] ; then
        echo Warning crabclient $release ${crab3_SCRAM_ARCH} installed according to $updated_list
        #return 0
     else
        printf "install_slc6_crab3 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
        currdir=$(pwd)
        cd
        cvmfs_server transaction
        status=$?
        what="install_slc6_crab3 ()"
        cvmfs_server_transaction_check $status $what
        if [ $? -eq 0 ] ; then
           echo INFO transaction OK for $what
        else
           printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
           cd $(currdir)
           return 1
        fi
        echo INFO adding crabclient $release ${crab3_SCRAM_ARCH} to $updated_list
        echo crabclient $release ${crab3_SCRAM_ARCH} $(/bin/date +%s) $(/bin/date -u) >> $updated_list
        currdir=$(pwd)
        cd
        time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish.log
        cd $currdir
        printf "install_crab3 () published  \n$(cat $HOME/logs/cvmfs_server+publish.log | sed 's#%#%%#g')\n" | mail -s "cvmfs_server publish Done" $notifytowhom
     fi
  done

  #for crab3repo in $crab3repos ; do
  crab3_RPMS=http://cmsrep.cern.ch/cmssw/${crab3_REPO}/RPMS/${crab3_SCRAM_ARCH}/
  echo INFO checking ${crab3_RPMS}

  crab3s=$(wget -O- $crab3_RPMS 2>/dev/null | grep cms+crabclient+ | cut -d\> -f7 | cut -d\< -f1 | sed 's#slc# slc#g' | sed 's#cms+crabclient+# #g' | sed 's#-1-1.# #g' | sed 's#.rpm##g' | awk '{print $1}')

  currdir=$(pwd)
  cd
  for release in $crab3s ; do
     echo "$release" | grep -q pre
     [ $? -eq 0 ] && { echo INFO skipping pre release per Marco\'s request ; continue ; } ;
     grep -q "crabclient $release ${crab3_SCRAM_ARCH} " $updated_list
     if [ $? -eq 0 ] ; then
        echo Warning crabclient $release ${crab3_SCRAM_ARCH} installed according to $updated_list
        continue
     fi
     if [ "x$cvmfs_server_yes" == "xno" ] ; then
        ls -al $HOME/slc*.lock 2>/dev/null 1>/dev/null
        if [ $? -eq 0 ] ; then
           echo Warning rsync may be in progress from the cvmfs server
           printf "install_slc6_crab3() Warning rsync may be in progress from the cvmfs server. We will wait for the next opportunity for crabclient $release ${crab3_SCRAM_ARCH} \n" | mail -s "[0] install_slc6_crab3() something is locked. Wait for the next opp." $notifytowhom
           continue
        fi
        ( printf "install_slc6_crab3() locking installation for crabclient $release ${crab3_SCRAM_ARCH}\n" | mail -s "[0] install_slc6_crab3() LOCK installation" $notifytowhom ; cd ; touch ${crab3_SCRAM_ARCH}.lock ; )
     fi
     printf "install_slc6_crab3 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
     cvmfs_server transaction
     status=$?
     what="install_slc6_crab3 ()"
     cvmfs_server_transaction_check $status $what
     if [ $? -eq 0 ] ; then
        echo INFO transaction OK for $what
     else
        printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
        cd $currdir
        return 1
     fi
     printf "install_slc6_crab3() installing crabclient ${release}+${crab3_SCRAM_ARCH} from $(/bin/hostname -f)\n" | mail -s "[0] install_slc6_crab3() installing crabclient ${release}" $notifytowhom
     echo INFO installing $release under $VO_CMS_SW_DIR : install_crab3.sh $VO_CMS_SW_DIR $release ${crab3_REPO} ${crab3_SCRAM_ARCH}
     $HOME/install_crab3.sh $VO_CMS_SW_DIR $release ${crab3_REPO} ${crab3_SCRAM_ARCH} > $HOME/install_crab3.log 2>&1 # 2>&1 | tee $HOME/install_crab3.log
     if [ $? -eq 0 ] ; then
        grep -q "crabclient $release ${crab3_SCRAM_ARCH} " $updated_list
        if [ $? -eq 0 ] ; then
           echo Warning crabclient $release for ${crab3_SCRAM_ARCH} installed
        else
           printf "install_slc6_crab3 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
           cvmfs_server transaction
           status=$?
           what="install_slc6_crab3 ()"
           cvmfs_server_transaction_check $status $what
           if [ $? -eq 0 ] ; then
              echo INFO transaction OK for $what
           else
              printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
              cd $currdir
              return 1
           fi
           echo INFO adding crabclient $release for ${crab3_SCRAM_ARCH} to local $updated_list
           echo crabclient ${release} ${crab3_SCRAM_ARCH} $(/bin/date +%s) $(/bin/date -u) >> $updated_list
           currdir=$(pwd)
           cd
           time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish.log
           cd $currdir
           printf "install_crab3 () published  \n$(cat $HOME/logs/cvmfs_server+publish.log | sed 's#%#%%#g')\n" | mail -s "cvmfs_server publish Done" $notifytowhom
           if [ "x$cvmfs_server_yes" == "xno" ] ; then # if [ ! -x /usr/bin/cvmfs_server ] ; then
             grep -q "CMSSW_crabclient ${release}+${crab3_SCRAM_ARCH}" "$HOME/${crab3_SCRAM_ARCH}.rsync.ready"
             [ $? -eq 0 ] || echo "CMSSW_crabclient ${release}+${crab3_SCRAM_ARCH}" >> "$HOME/${crab3_SCRAM_ARCH}.rsync.ready"
           fi
           printf "install_slc6_crab3() crabclient ${release}+${crab3_SCRAM_ARCH} installed from $(/bin/hostname -f)\n$(cat $HOME/install_crab3.log | sed 's#%#%%#g')\n" | mail -s "[1] install_slc6_crab3() crabclient INSTALLED" $notifytowhom
           #echo INFO no cvmfs server. will tell the main script not to publish
        fi
     else
           printf "FAILED: install_slc6_crab3() crabclient ${release}+${crab3_SCRAM_ARCH} from $(/bin/hostname -f)\n$(cat $HOME/install_crab3.log | sed 's#%#%%#g')\n" | mail -s "[1] FAILED: install_slc6_crab3() crabclient installation" $notifytowhom
     fi
  done
  #done

  return 0
}


function install_slc6_amd64_gcc493_crab3 () {
  export crab3_REPO=comp # $crab3repos 
  export crab3_SCRAM_ARCH=slc6_amd64_gcc493  
  export SCRAM_ARCH=$crab3_SCRAM_ARCH
  
  #crab3_RPMS=http://cmsrep.cern.ch/cmssw/${crab3_REPO}/RPMS/${crab3_SCRAM_ARCH}/
  #echo INFO checking ${crab3_RPMS}

  #crab3s=$(wget -O- $crab3_RPMS 2>/dev/null | grep cms+crabclient+ | cut -d\> -f7 | cut -d\< -f1 | sed 's#slc# slc#g' | sed 's#cms+crabclient+# #g' | sed 's#-1-1.# #g' | sed 's#.rpm##g' | awk '{print $1}')
  
  cvmfs_server transaction 2>&1 | tee $HOME/logs/cvmfs_server+transaction.log
  [ $? -eq 0 ] || { printf "ERROR: function install_slc6_amd64_gcc493_crab3 cvmfs_server transaction failed\n$(cat $HOME/logs/cvmfs_server+transaction.log)\n" | mail -s "ERROR: cvmfs_server transaction failed for the crab3-client installation" $notifytowhom ; ( cd ; cvmfs_server abort -f ; ) ; return 1 ; } ;
  
  export MYTESTAREA=$VO_CMS_SW_DIR/crab3
  CMSPKG="$MYTESTAREA/common/cmspkg -a $SCRAM_ARCH"
  if [ -f $MYTESTAREA/common/cmspkg ] ; then
     echo INFO We use cmspkg
  else
     (
      cd /tmp
      echo INFO downloading cmspkg.py
      wget -O cmspkg.py https://raw.githubusercontent.com/cms-sw/cmspkg/production/client/cmspkg.py

      [ $? -eq 0 ] || { echo ERROR wget cmspkg.py failed ; rm -f cmspkg.py ; cd - ; ( cd ; cvmfs_server abort -f ; ) ; return 1 ; } ;

      python cmspkg.py --architecture $SCRAM_ARCH --path $MYTESTAREA --repository $crab3_REPO setup
      status=$?
      [ -f $MYTESTAREA/common/cmspkg ] || { echo ERROR cmspkg is not installed ; rm -f cmspkg.py ; return 1 ; } ;
      rm -f cmspkg.py
      cd
      return $status
     )
     [ $? -eq 0 ] || { printf "$(basename $0) $MYTESTAREA/common/cmspkg does not exist\nUse \nsource $HOME/cron_install_cmssw-functions\ndeploy_cmspkg /cvmfs/cms.cern.ch/phedexagents slc6_amd64_gcc494 comp\n" | mail -s "ERROR: $MYTESTAREA/common/cmspkg does not exist" $notifytowhom ; ( cd ; cvmfs_server abort -f ; ) ;return 1 ; } ;
  fi
  echo INFO executing $CMSPKG -y upgrade
  $CMSPKG -y upgrade
  status=$?
  if [ $status -ne 0 ] ; then
     echo ERROR $CMSPKG -y upgrade upgrade failed
     ( cd ; cvmfs_server abort -f ; ) ;
     return 1
  fi
  $CMSPKG update 2>&1
  status=$?
  if [ $status -ne 0 ] ; then
     echo ERROR $CMSPKG update failed
     ( cd ; cvmfs_server abort -f ; ) ;
     return 1
  fi

  crab3s=$($CMSPKG search cms+crabclient+ | awk '{print $1}' | sed 's#cms+crabclient+##g')
  ( cd ; cvmfs_server abort -f ; ) ; # do not apply the change yet

  currdir=$(pwd)
  cd
  for release in $crab3s ; do
     echo "$release" | grep -q pre
     [ $? -eq 0 ] && { echo INFO skipping pre release per Marco\'s request ; continue ; } ;
     #grep -q "crabclient$release ${crab3_SCRAM_ARCH} " $updated_list
     grep -q "crabclient $release ${crab3_SCRAM_ARCH} " $updated_list
     if [ $? -eq 0 ] ; then
        echo Warning crabclient $release ${crab3_SCRAM_ARCH} installed according to $updated_list
        continue
     fi
     if [ "x$cvmfs_server_yes" == "xno" ] ; then
        ls -al $HOME/slc*.lock 2>/dev/null 1>/dev/null
        if [ $? -eq 0 ] ; then
           echo Warning rsync may be in progress from the cvmfs server
           printf "install_slc6_amd64_gcc493_crab3() Warning rsync may be in progress from the cvmfs server. We will wait for the next opportunity for crabclient $release ${crab3_SCRAM_ARCH} \n" | mail -s "[0] install_slc6_amd64_gcc493_crab3() something is locked. Wait for the next opp." $notifytowhom
           continue
        fi
        ( printf "install_slc6_amd64_gcc493_crab3() locking installation for crabclient $release ${crab3_SCRAM_ARCH}\n" | mail -s "[0] install_slc6_amd64_gcc493_crab3() LOCK installation" $notifytowhom ; cd ; touch ${crab3_SCRAM_ARCH}.lock ; )
     fi
     printf "install_slc6_amd64_gcc493_crab3 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
     cvmfs_server transaction
     status=$?
     what="install_slc6_amd64_gcc493_crab3 ()"
     cvmfs_server_transaction_check $status $what
     if [ $? -eq 0 ] ; then
        echo INFO transaction OK for $what
     else
        printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
        cd $currdir
        return 1
     fi
     printf "install_slc6_amd64_gcc493_crab3() installing crabclient ${release}+${crab3_SCRAM_ARCH} from $(/bin/hostname -f)\n" | mail -s "[0] install_slc6_amd64_gcc493_crab3() installing crabclient ${release}" $notifytowhom
     echo INFO installing $release under $VO_CMS_SW_DIR : install_crab3.sh $VO_CMS_SW_DIR $release ${crab3_REPO} ${crab3_SCRAM_ARCH}
     $HOME/install_crab3.sh $VO_CMS_SW_DIR $release ${crab3_REPO} ${crab3_SCRAM_ARCH} > $HOME/logs/install_crab3.${release}.log 2>&1
     status=$?
     printf "New CRAB3 Client Installed with status=$?\n$(cat $HOME/logs/install_crab3.${release}.log | sed 's#%#%%#g')\n" | mail -s "INFO: New CRAB3 Client Installed" $notifytowhom
     #cp /dev/null $HOME/install_crab3.log
     echo DEBUG status=$status at install_slc6_amd64_gcc493_crab3
     if [ $status -eq 0 ] ; then
        grep -q "crabclient $release ${crab3_SCRAM_ARCH} " $updated_list
        if [ $? -eq 0 ] ; then
           echo Warning crabclient $release for ${crab3_SCRAM_ARCH} installed
        else
           printf "install_slc6_amd64_gcc493_crab3 () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
           cvmfs_server transaction
           status=$?
           what="install_slc6_amd64_gcc493_crab3 ()"
           cvmfs_server_transaction_check $status $what
           if [ $? -eq 0 ] ; then
              echo INFO transaction OK for $what
           else
              printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
              cd $currdir
              return 1
           fi
           echo INFO adding crabclient $release for ${crab3_SCRAM_ARCH} to local $updated_list
           echo crabclient ${release} ${crab3_SCRAM_ARCH} $(/bin/date +%s) $(/bin/date -u) >> $updated_list
           currdir=$(pwd)
           cd
           time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish.log
           cd $currdir
           printf "install_crab3 () published  \n$(cat $HOME/logs/cvmfs_server+publish.log | sed 's#%#%%#g')\n" | mail -s "cvmfs_server publish Done" $notifytowhom
           if [ "x$cvmfs_server_yes" == "xno" ] ; then # if [ ! -x /usr/bin/cvmfs_server ] ; then
             grep -q "CMSSW_crabclient ${release}+${crab3_SCRAM_ARCH}" "$HOME/${crab3_SCRAM_ARCH}.rsync.ready"
             [ $? -eq 0 ] || echo "CMSSW_crabclient ${release}+${crab3_SCRAM_ARCH}" >> "$HOME/${crab3_SCRAM_ARCH}.rsync.ready"
           fi
           printf "install_slc6_amd64_gcc493_crab3() crabclient ${release}+${crab3_SCRAM_ARCH} installed from $(/bin/hostname -f)\n$(cat $HOME/install_crab3.${release}.log | sed 's#%#%%#g')\n" | mail -s "[1] install_slc6_amd64_gcc493_crab3() crabclient INSTALLED" $notifytowhom
           #echo INFO no cvmfs server. will tell the main script not to publish
        fi
     else
        printf "FAILED: install_slc6_amd64_gcc493_crab3() crabclient ${release}+${crab3_SCRAM_ARCH} from $(/bin/hostname -f)\n$(cat $HOME/install_crab3.${release}.log | sed 's#%#%%#g')\n" | mail -s "[1] FAILED: install_slc6_amd64_gcc493_crab3() crabclient installation" $notifytowhom
        ( cd ; cvmfs_server abort -f ; ) ;
     fi
     #break
  done
  #done

  return 0
}

function install_slc6_amd64_gcc493_phedexagents () {
  export phedexagents_REPO=comp
  export phedexagents_SCRAM_ARCH=slc6_amd64_gcc493
  export SCRAM_ARCH=$phedexagents_SCRAM_ARCH
  
  cvmfs_server transaction 2>&1 | tee $HOME/logs/cvmfs_server+transaction.log
  [ $? -eq 0 ] || { printf "ERROR: function install_slc6_amd64_gcc493_phedexagents cvmfs_server transaction failed\n$(cat $HOME/logs/cvmfs_server+transaction.log)\n" | mail -s "ERROR: cvmfs_server transaction failed for the phedexagent installation" $notifytowhom ; ( cd ; cvmfs_server abort -f ; ) ; return 1 ; } ;
  
  export MYTESTAREA=$VO_CMS_SW_DIR/phedex
  CMSPKG="$MYTESTAREA/common/cmspkg -a $SCRAM_ARCH"
  if [ -f $MYTESTAREA/common/cmspkg ] ; then
     echo INFO We use cmspkg
  else
     (
      cd /tmp
      echo INFO downloading cmspkg.py
      wget -O cmspkg.py https://raw.githubusercontent.com/cms-sw/cmspkg/production/client/cmspkg.py

      [ $? -eq 0 ] || { echo ERROR wget cmspkg.py failed ; rm -f cmspkg.py ; cd - ; ( cd ; cvmfs_server abort -f ; ) ; return 1 ; } ;

      python cmspkg.py --architecture $SCRAM_ARCH --path $MYTESTAREA --repository $phedexagents_REPO setup
      status=$?
      [ -f $MYTESTAREA/common/cmspkg ] || { echo ERROR cmspkg is not installed ; rm -f cmspkg.py ; return 1 ; } ;
      rm -f cmspkg.py
      cd
      return $status
     )
     [ $? -eq 0 ] || { printf "$(basename $0) $MYTESTAREA/common/cmspkg does not exist\nUse \nsource $HOME/cron_install_cmssw-functions\ndeploy_cmspkg /cvmfs/cms.cern.ch/phedexagents slc6_amd64_gcc494 comp\n" | mail -s "ERROR: $MYTESTAREA/common/cmspkg does not exist" $notifytowhom ; ( cd ; cvmfs_server abort -f ; ) ;return 1 ; } ;
  fi
  echo INFO executing $CMSPKG -y upgrade
  $CMSPKG -y upgrade
  status=$?
  if [ $status -ne 0 ] ; then
     echo ERROR $CMSPKG -y upgrade upgrade failed
     ( cd ; cvmfs_server abort -f ; ) ;
     return 1
  fi
  $CMSPKG update 2>&1
  status=$?
  if [ $status -ne 0 ] ; then
     echo ERROR $CMSPKG update failed
     ( cd ; cvmfs_server abort -f ; ) ;
     return 1
  fi

  phedexagentss=$($CMSPKG search cms+PHEDEX+ | awk '{print $1}' | sed 's#cms+PHEDEX+##g')
  ( cd ; cvmfs_server abort -f ; ) ; # do not apply the change yet

  currdir=$(pwd)
  cd
  for release in $phedexagentss ; do
     echo $release | grep -q "4.1.4\|4.1.5\|4.1.7\|4.1.7-comp\|4.1.8\|4.2.0pre2"
     [ $? -eq 0 ] && continue
     grep -q "PhEDExAgents $release ${phedexagents_SCRAM_ARCH} " $updated_list
     if [ $? -eq 0 ] ; then
        echo Warning PhEDExAgents $release ${phedexagents_SCRAM_ARCH} installed according to $updated_list
        continue
     fi
     printf "install_slc6_amd64_gcc493_phedexagents () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
     cvmfs_server transaction
     status=$?
     what="install_slc6_amd64_gcc493_phedexagents ()"
     cvmfs_server_transaction_check $status $what
     if [ $? -eq 0 ] ; then
        echo INFO transaction OK for $what
     else
        printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
        cd $currdir
        return 1
     fi
     printf "install_slc6_amd64_gcc493_phedexagents() installing PhEDExAgents ${release}+${phedexagents_SCRAM_ARCH} from $(/bin/hostname -f)\n" | mail -s "[0] install_slc6_amd64_gcc493_phedexagents() installing PhEDExAgents ${release}" $notifytowhom
     echo INFO installing $release under $VO_CMS_SW_DIR : install_phedexagents.sh $VO_CMS_SW_DIR $release ${phedexagents_REPO} ${phedexagents_SCRAM_ARCH}
     $HOME/install_phedexagents.sh $VO_CMS_SW_DIR $release ${phedexagents_REPO} ${phedexagents_SCRAM_ARCH} > $HOME/logs/install_phedexagents.${release}.log 2>&1
     status=$?
     [ $status -eq 0 ] && printf "New PHEDEXAGENTS Client Installed with status=$?\n$(cat $HOME/logs/install_phedexagents.${release}.log | sed 's#%#%%#g')\n" | mail -s "INFO: New PHEDEXAGENTS Client Installed" $notifytowhom
     
     echo DEBUG status=$status at install_slc6_amd64_gcc493_phedexagents
     if [ $status -eq 0 ] ; then
        grep -q "PhEDExAgents $release ${phedexagents_SCRAM_ARCH} " $updated_list
        if [ $? -eq 0 ] ; then
           echo Warning PhEDExAgents $release for ${phedexagents_SCRAM_ARCH} installed
        else
           printf "install_slc6_amd64_gcc493_phedexagents () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
           cvmfs_server transaction
           status=$?
           what="install_slc6_amd64_gcc493_phedexagents ()"
           cvmfs_server_transaction_check $status $what
           if [ $? -eq 0 ] ; then
              echo INFO transaction OK for $what
           else
              printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
              cd $currdir
              return 1
           fi
           echo INFO adding PhEDExAgents $release for ${phedexagents_SCRAM_ARCH} to local $updated_list
           echo PhEDExAgents ${release} ${phedexagents_SCRAM_ARCH} $(/bin/date +%s) $(/bin/date -u) >> $updated_list
           currdir=$(pwd)
           cd
           time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish.log
           cd $currdir
           printf "install_slc6_amd64_gcc493_phedexagents() PhEDExAgents ${release}+${phedexagents_SCRAM_ARCH} installed/published from $(/bin/hostname -f)\n$(cat $HOME/logs/install_phedexagents.${release}.log | sed 's#%#%%#g')\n" | mail -s "[1] install_slc6_amd64_gcc493_phedexagents() PhEDExAgents INSTALLED" $notifytowhom
           #echo INFO no cvmfs server. will tell the main script not to publish
        fi
     else
        printf "FAILED: install_slc6_amd64_gcc493_phedexagents() PhEDExAgents ${release}+${phedexagents_SCRAM_ARCH} from $(/bin/hostname -f)\n$(cat $HOME/logs/install_phedexagents.${release}.log | sed 's#%#%%#g')\n" | mail -s "[1] FAILED: install_slc6_amd64_gcc493_phedexagents() PhEDExAgents installation" $notifytowhom
        ( cd ; cvmfs_server abort -f ; ) ;
     fi
     
  done

  return 0
}


function install_slc6_amd64_gcc493_spacemonclient () {
  export spacemonclient_REPO=comp
  export spacemonclient_SCRAM_ARCH=slc6_amd64_gcc493  
  export SCRAM_ARCH=slc6_amd64_gcc493  
  
  #spacemonclient_RPMS=http://cmsrep.cern.ch/cmssw/${spacemonclient_REPO}/RPMS/${spacemonclient_SCRAM_ARCH}/
  #echo INFO checking ${spacemonclient_RPMS}

  #spacemonclients=$(wget -O- $spacemonclient_RPMS 2>/dev/null | grep cms+spacemon-client+ | cut -d\> -f7 | cut -d\< -f1 | sed 's#slc# slc#g' | sed 's#cms+spacemon-client+# #g' | sed 's#-1-1.# #g' | sed 's#.rpm##g' | awk '{print $1}')
  
  cvmfs_server transaction 2>&1 | tee $HOME/logs/cvmfs_server+transaction.log
  [ $? -eq 0 ] || { printf "ERROR: function install_slc6_amd64_gcc493_spacemonclient cvmfs_server transaction failed\n$(cat $HOME/logs/cvmfs_server+transaction.log)\n" | mail -s "ERROR: cvmfs_server transaction failed for the spacemonclient installation" $notifytowhom ; ( cd ; cvmfs_server abort -f ; ) ; return 1 ; } ;
  
  export MYTESTAREA=$VO_CMS_SW_DIR/spacemon-client
  CMSPKG="$MYTESTAREA/common/cmspkg -a $SCRAM_ARCH"
  if [ -f $MYTESTAREA/common/cmspkg ] ; then
     echo INFO We use cmspkg
  else
     (
      cd /tmp
      echo INFO downloading cmspkg.py
      wget -O cmspkg.py https://raw.githubusercontent.com/cms-sw/cmspkg/production/client/cmspkg.py

      [ $? -eq 0 ] || { echo ERROR wget cmspkg.py failed ; rm -f cmspkg.py ; cd - ; ( cd ; cvmfs_server abort -f ; ) ; return 1 ; } ;

      python cmspkg.py --architecture $SCRAM_ARCH --path $MYTESTAREA --repository $spacemonclient_REPO setup
      status=$?
      [ -f $MYTESTAREA/common/cmspkg ] || { echo ERROR cmspkg is not installed ; rm -f cmspkg.py ; return 1 ; } ;
      rm -f cmspkg.py
      cd
      return $status
     )
     [ $? -eq 0 ] || { printf "$(basename $0) $MYTESTAREA/common/cmspkg does not exist\nUse \nsource $HOME/cron_install_cmssw-functions\ndeploy_cmspkg /cvmfs/cms.cern.ch/spacemon-client slc6_amd64_gcc494 comp\n" | mail -s "ERROR: $MYTESTAREA/common/cmspkg does not exist" $notifytowhom ; ( cd ; cvmfs_server abort -f ; ) ;return 1 ; } ;
  fi
  echo INFO executing $CMSPKG -y upgrade
  $CMSPKG -y upgrade
  status=$?
  if [ $status -ne 0 ] ; then
     echo ERROR $CMSPKG -y upgrade upgrade failed
     ( cd ; cvmfs_server abort -f ; ) ;
     return 1
  fi
  $CMSPKG update 2>&1
  status=$?
  if [ $status -ne 0 ] ; then
     echo ERROR $CMSPKG update failed
     ( cd ; cvmfs_server abort -f ; ) ;
     return 1
  fi

  spacemonclients=$($CMSPKG search cms+spacemon-client+ | awk '{print $1}' | sed 's#cms+spacemon-client+##g')
  ( cd ; cvmfs_server abort -f ; ) ; # do not apply the change yet

  currdir=$(pwd)
  cd
  for release in $spacemonclients ; do
     #echo $release | grep -q "4.1.4\|4.1.5\|4.1.7\|4.1.7-comp\|4.1.8\|4.2.0pre2"
     #[ $? -eq 0 ] && continue
     grep -q "spacemon-client $release ${spacemonclient_SCRAM_ARCH} " $updated_list
     if [ $? -eq 0 ] ; then
        echo Warning spacemon-client $release ${spacemonclient_SCRAM_ARCH} installed according to $updated_list
        continue
     fi
     printf "install_slc6_amd64_gcc493_spacemonclient () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
     cvmfs_server transaction
     status=$?
     what="install_slc6_amd64_gcc493_spacemonclient ()"
     cvmfs_server_transaction_check $status $what
     if [ $? -eq 0 ] ; then
        echo INFO transaction OK for $what
     else
        printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
        cd $currdir
        return 1
     fi
     printf "install_slc6_amd64_gcc493_spacemonclient() installing Spacemonclient ${release}+${spacemonclient_SCRAM_ARCH} from $(/bin/hostname -f)\n" | mail -s "[0] install_slc6_amd64_gcc493_spacemonclient() installing Spacemonclient ${release}" $notifytowhom
     echo INFO installing $release under $VO_CMS_SW_DIR : install_spacemonclient.sh $VO_CMS_SW_DIR $release ${spacemonclient_REPO} ${spacemonclient_SCRAM_ARCH}
     $HOME/install_spacemonclient.sh $VO_CMS_SW_DIR $release ${spacemonclient_REPO} ${spacemonclient_SCRAM_ARCH} > $HOME/logs/install_spacemonclient.${release}.log 2>&1
     status=$?
     [ $status -eq 0 ] && printf "New SPACEMONCLIENT Client Installed with status=$?\n$(cat $HOME/logs/install_spacemonclient.${release}.log | sed 's#%#%%#g')\n" | mail -s "INFO: New SPACEMONCLIENT Client Installed" $notifytowhom
     
     echo DEBUG status=$status at install_slc6_amd64_gcc493_spacemonclient
     if [ $status -eq 0 ] ; then
        grep -q "Spacemonclient $release ${spacemonclient_SCRAM_ARCH} " $updated_list
        if [ $? -eq 0 ] ; then
           echo Warning Spacemonclient $release for ${spacemonclient_SCRAM_ARCH} installed
        else
           printf "install_slc6_amd64_gcc493_spacemonclient () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
           cvmfs_server transaction
           status=$?
           what="install_slc6_amd64_gcc493_spacemonclient ()"
           cvmfs_server_transaction_check $status $what
           if [ $? -eq 0 ] ; then
              echo INFO transaction OK for $what
           else
              printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
              cd $currdir
              return 1
           fi
           echo INFO adding spacemon-client $release for ${spacemonclient_SCRAM_ARCH} to local $updated_list
           echo spacemon-client ${release} ${spacemonclient_SCRAM_ARCH} $(/bin/date +%s) $(/bin/date -u) >> $updated_list
           currdir=$(pwd)
           cd
           time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish.log
           cd $currdir
           #printf "install_spacemonclient () published  \n$(cat $HOME/logs/cvmfs_server+publish.log | sed 's#%#%%#g')\n" | mail -s "cvmfs_server publish Done" $notifytowhom
           printf "install_slc6_amd64_gcc493_spacemonclient() Spacemonclient ${release}+${spacemonclient_SCRAM_ARCH} installed/published from $(/bin/hostname -f)\n$(cat $HOME/logs/install_spacemonclient.${release}.log | sed 's#%#%%#g')\n" | mail -s "[1] install_slc6_amd64_gcc493_spacemonclient() Spacemonclient INSTALLED" $notifytowhom
           #echo INFO no cvmfs server. will tell the main script not to publish
        fi
     else
        printf "FAILED: install_slc6_amd64_gcc493_spacemonclient() Spacemonclient ${release}+${spacemonclient_SCRAM_ARCH} from $(/bin/hostname -f)\n$(cat $HOME/logs/install_spacemonclient.${release}.log | sed 's#%#%%#g')\n" | mail -s "[1] FAILED: install_slc6_amd64_gcc493_spacemonclient() Spacemonclient installation" $notifytowhom
        ( cd ; cvmfs_server abort -f ; ) ;
     fi
     #break
  done
  #done

  return 0
}

function install_comp_python () {
  release_arch_repos="2.6.8-comp9+slc6_amd64_gcc481+comp.pre 2.7.6+slc6_amd64_gcc493+comp"

if [ ] ;  then
  for release_arch_repo in $release_arch_repos ; do
     release=$(echo $release_arch_repo | cut -d+ -f1)
     thearch=$(echo $release_arch_repo | cut -d+ -f2)
     grep -q "COMP+python+${release} ${thearch} " $updated_list
     if [ $? -eq 0 ] ; then
        echo Warning COMP+python+${release} ${thearch} installed according to $updated_list
     else
        printf "install_comp_python () Starting cvmfs_server transaction\n" | mail -s "cvmfs_server transaction started" $notifytowhom
        currdir=$(pwd)
        cd
        cvmfs_server transaction
        status=$?
        what="install_comp_python ()"
        cvmfs_server_transaction_check $status $what
        if [ $? -eq 0 ] ; then
           echo INFO transaction OK for $what
        else
           printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
           cd $(currdir)
           return 1
        fi
        echo INFO adding COMP+python+$release $thearch to $updated_list
        echo COMP+python+$release ${thearch} $(/bin/date +%s) $(/bin/date -u) >> $updated_list
        currdir=$(pwd)
        cd
        time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish.log
        cd $currdir
        printf "install_comp_python () published  \n$(cat $HOME/logs/cvmfs_server+publish.log | sed 's#%#%%#g')\n" | mail -s "cvmfs_server publish Done" $notifytowhom
     fi
  done
fi # if [ ] ; then

  currdir=$(pwd)
  cd
  for release_arch_repo in $release_arch_repos ; do
     release=$(echo $release_arch_repo | cut -d+ -f1)
     thearch=$(echo $release_arch_repo | cut -d+ -f2)
     therepo=$(echo $release_arch_repo | cut -d+ -f3)
     echo DEUBG Doing $release $thearch $therepo
     grep -q "COMP+python+${release} ${thearch} " $updated_list
     if [ $? -eq 0 ] ; then
        echo Warning COMP+python+$release ${thearch} installed according to $updated_list
        continue
     fi
     cvmfs_server transaction
     status=$?
     what="install_comp_python ()"
     cvmfs_server_transaction_check $status $what
     if [ $? -eq 0 ] ; then
        echo INFO transaction OK for $what
     else
        printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom
        cd $currdir
        return 1
     fi
     echo INFO installing $release under $VO_CMS_SW_DIR : install_comp_python.sh $VO_CMS_SW_DIR $release ${therepo} ${thearch}
     $HOME/install_comp_python.sh $VO_CMS_SW_DIR $release ${therepo} ${thearch} > $HOME/logs/install_comp_python.log 2>&1 # | tee $HOME/install_comp_python.log
     if [ $? -eq 0 ] ; then
        grep -q "COMP+python+$release ${thearch} " $updated_list
        if [ $? -eq 0 ] ; then
           echo Warning COMP+python+$release for ${thearch} installed
        else
           echo INFO adding COMP+python+$release for ${thearch} to local $updated_list
           echo COMP+python+${release} ${thearch} $(/bin/date +%s) $(/bin/date -u) >> $updated_list
           currdir=$(pwd)
           cd
           time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish.log
           cd $currdir
           printf "install_comp_python () installed from $(/bin/hostname -f)\n$(cat $HOME/logs/install_comp_python.log | sed 's#%#%%#g')\n and published  \n$(cat $HOME/logs/cvmfs_server+publish.log | sed 's#%#%%#g')\n" | mail -s "INFO install_comp_python () COMP+python+$release $thearch INSTALLED/PUBLISHED" $notifytowhom
        fi
     else
        printf "FAILED: install_comp_python () COMP+python+${release}+${thearch} from $(/bin/hostname -f)\n$(cat $HOME/logs/install_comp_python.log | sed 's#%#%%#g')\n" | mail -s "FAILED: install_comp_python () COMP+python installation" $notifytowhom
     fi
  done

  return 0
}

# this is not used any more
function install_aarch64 () {
  ls -al $updated_list
  if [ $? -ne 0 ] ; then
     echo ERROR install_aarch64 $updated_list not found /cvmfs/cms.cern.ch may not be mounted properly
     return 1
  fi
  aarch64_tarball_web=http://davidlt.web.cern.ch/davidlt/vault/aarch64
  export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
  aarch64_release_tarballs=$(/usr/bin/wget -q -O- $aarch64_tarball_web | grep tar.gz | sed "s#</a>#|#g" | cut -d\| -f1 | sed "s#CMSSW_# CMSSW_#g" | awk '{print $NF}')
  currdir=$(pwd)
  cd
  for tarball in $aarch64_release_tarballs ; do
     cmssw=$(echo $tarball | cut -d. -f1)
     aarch=$(echo $tarball | cut -d. -f2)
     grep -q "$cmssw $aarch " $updated_list
     if [ $? -eq 0 ] ; then
        echo INFO "$cmssw $aarch " found in $updated_list
        continue
     fi
     echo INFO "Starting aarch installation" "$cmssw $aarch "
     #printf "install_aarch64:\nStarting installation of $tarball" | mail -s "install_aarch64 $targall" $notifytowhom
     printf "install_aarch64 Starting cvmfs_server transaction for $tarball\n" | mail -s "cvmfs_server transaction started" $notifytowhom
     cvmfs_server transaction
     status=$?
     what="install_aarch64 ()"
     cvmfs_server_transaction_check $status $what
     if [ $? -eq 0 ] ; then
        echo INFO transaction OK for $what
     else
        printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
        cd $currdir
        return 1
     fi
    
     ( cd $VO_CMS_SW_DIR
     # 1 download
       if [ -f $VO_CMS_SW_DIR/$tarball ] ; then
          echo INFO tarball exists
       else
          echo INFO downloading tarball: /usr/bin/wget -q -O $tarball $aarch64_tarball_web/$tarball
       fi
       if [ $? -ne 0 ] ; then
          echo ERROR failed: /usr/bin/wget -O $tarball $aarch64_tarball_web/$tarball
          ( cd ; cvmfs_server abort -f ; ) ; #cvmfs_server abort -f
          return 1
       fi
     # 2 install
       tar xzvf $tarball
       if [ $? -ne 0 ] ; then
          echo ERROR failed: tar xzvf $tarball
          #cvmfs_server abort -f
          return 1
       fi
     )
     if [ $? -ne 0 ] ; then
        echo ERROR failed to install $tarball
        ( cd ; cvmfs_server abort -f ; ) ; #cvmfs_server abort -f
        return 1
     fi
     if [ -d $VO_CMS_SW_DIR/$aarch ] ; then
     # 3 nested stuff /cvmfs/cms.cern.ch/.cvmfsdirtab and /cvmfs/cms.cern.ch/<arch>/.cvmfscatalog
         echo INFO adding $aarch to /cvmfs/cms.cern.ch/.cvmfsdirtab
	 add_nested_entry_to_cvmfsdirtab $aarch
         ls -al $VO_CMS_SW_DIR/${aarch}/.cvmfscatalog 2>/dev/null 1>/dev/null
         if [ $? -eq 0 ] ; then
            echo INFO $VO_CMS_SW_DIR/${aarch}/.cvmfscatalog exists
         else
            echo INFO creating $VO_CMS_SW_DIR/${aarch}/.cvmfscatalog
            touch $VO_CMS_SW_DIR/${aarch}/.cvmfscatalog
            # 4 publish the installation
            publish_cmssw_cvmfs install_aarch64_for_$cmssw_$aarch
            grep -q "$cmssw $aarch " $updated_list
            if [ $? -eq 0 ] ; then
               echo INFO "$cmssw $aarch " found in $updated_list
            else
               currdir_1=$(pwd)
               cd
               cvmfs_server transaction
               status=$?
               what="adding_$cmssw_$aarch"
               cvmfs_server_transaction_check $status $what
               echo INFO adding $cmssw $aarch to $updated_list
               echo $cmssw $aarch $(/bin/date +%s) $(/bin/date -u) >> $updated_list
               printf "install_aarch64:\n$cmssw $aarch installed " | mail -s "install_aarch64 $aarch installed" $notifytowhom
               ( cd ; cvmfs_server abort -f ; ) ; #cvmfs_server abort -f
               rm -f $VO_CMS_SW_DIR/$tarball
               cd $currdir_1
            fi
         fi
     else
         printf "Warning: install_aarch64:\n$cmssw $aarch not installed " | mail -s "Warning: install_aarch64 $aarch not installed" $notifytowhom
     fi
  done
  cd $currdir
  return 0
}

function cvmfs_server_transaction_check () {
   status=$1
   what="$2"
   ntry=10
   itry=0
   currdir=$(pwd)
   cd
   while [ $itry -lt $ntry ] ; do
     if [ $status -eq 0 ] ; then
      cd $currdir
      return 0
     else
      
      if [ $itry -eq $(expr $ntry - 1) ] ; then
         cvmfs_server abort -f
         cvmfs_server transaction > $HOME/cvmfs_server+transaction.log 2>&1 # | tee $HOME/cvmfs_server+transaction.log
         [ $? -eq 0 ] && { cd $currdir ; return 0 ; } ;
         printf "$what at $(pwd) cvmfs_server transaction Failing\n$(cat $HOME/cvmfs_server+transaction.log | sed 's#%#%%#g')\n" | mail -s "ERROR cvmfs_server transaction Failed" $notifytowhom
         #cvmfs_server abort -f
      fi
      echo INFO retrying $itry
      cvmfs_server abort -f
      cvmfs_server transaction
      status=$?
      [ $status -eq 0 ] && { cd $currdir ; return 0 ; } ;
     fi
     itry=$(expr $itry + 1)
   done
   cd $currdir
   return 1
}

function update_CMS_at_Home () {
   cvmfs_server transaction
   status=$?
   what="update_CMS_at_Home ()"
   cvmfs_server_transaction_check $status $what
   if [ $? -eq 0 ] ; then
      echo INFO transaction OK for $what
   else
      printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
      cd $currdir
      return 1
   fi
   # ls /cvmfs/cms.cern.ch/CMS@Home
   [ -d /cvmfs/cms.cern.ch/CMS@Home ] || mkdir /cvmfs/cms.cern.ch/CMS@Home
   status=0
   echo DEBUG check point will execute git
   if [ -d $HOME/CMS@Home ] ; then
      ( cd $HOME/CMS@Home ; git pull origin master ; status=$? ; exit $status ) > $HOME/CMS_at_HOME_git.log 2>&1 # | tee $HOME/CMS_at_HOME_git.log
      status=$?
      grep -q "Already up-to-date" $HOME/CMS_at_HOME_git.log
      if [ $? -eq 0 ] ; then
         printf "CMS_at_Home INFO git repo shows no update\n"
         #printf "CMS_at_Home INFO git repo shows no update\n" | mail -s "CMS_at_Home INFO git repo shows no update" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         return 0
      fi
   else
      #printf "CMS_at_Home INFO git clone is executed\n" | mail -s "CMS_at_Home INFO git clone is executed" $notifytowhom
      ( cd ; git clone http://git.cern.ch/pub/CMS_at_Home CMS@Home ; status=$? ; exit $status )
      status=$?
   fi
   if [ $status -ne 0 ] ; then
      printf "CMS_at_Home ERROR git failed\n" | mail -s "CMS_at_Home ERROR git failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
   rsync_source="$HOME/CMS@Home"
   rsync_name="/cvmfs/cms.cern.ch/CMS@Home"
   echo DEBUG check point will execute 
   echo rsync -arzuvp $rsync_source $(dirname $rsync_name)
   #printf "CMS_at_Home INFO rsync -arzuvp $rsync_source $(dirname $rsync_name)\n" | mail -s "CMS_at_Home INFO rsync " $notifytowhom

   rm -f $HOME/CMS_at_HOME_rsync.log
   rsync -arzuvp $rsync_source $(dirname $rsync_name) > $HOME/CMS_at_HOME_rsync.log 2>&1 # | tee $HOME/CMS_at_HOME_rsync.log
   if [ $? -eq 0 ] ; then
      publish_needed=0
      i=0
      for f in $(grep ^$(basename $rsync_source) $HOME/CMS_at_HOME_rsync.log | grep -v .git/ 2>/dev/null) ; do
         i=$(expr $i + 1)
         [ -f "$(dirname $rsync_name)/$f" ] || { echo "[ $i ] " $(dirname $rsync_name)/$f is not a file $publish_needed ; continue ; } ;
         publish_needed=1
         echo "[ $i ] " $(dirname $rsync_name)/$f is a file $publish_needed
      done

      echo INFO check point publish_needed $publish_needed

      if [ $publish_needed -eq 0 ] ; then
         echo INFO publish was not needed, So ending the transaction
         ( cd ; cvmfs_server abort -f ; ) ;
         #printf "CMS_at_Home INFO publish was not needed\n $(cat $HOME/CMS_at_HOME_rsync.log | sed 's#%#%%#g')\n" | mail -s "CMS_at_Home INFO publish was not needed " $notifytowhom

      else
         #printf "CMS_at_Home INFO publish is necessary\n $(cat $HOME/CMS_at_HOME_rsync.log | sed 's#%#%%#g')\n" | mail -s "CMS_at_Home INFO publish is necessary " $notifytowhom
         echo INFO publish necessary
         echo INFO updating $updated_list
         # db updated_list
         date_s_now=$(echo $(/bin/date +%s) $(/bin/date -u))
         grep -q "CMS@Home $(echo $f | cut -d/ -f2) $(echo $date_s_now | awk '{print $1}')" $updated_list
         if [ $? -eq 0 ] ; then
           echo Warning "CMS@Home $(echo $f | cut -d/ -f2) $(echo $date_s_now | awk '{print $1}')" is already in the $updated_list
         else
           echo INFO adding "CMS@Home $(echo $f | cut -d/ -f2) $(echo $date_s_now | awk '{print $1}')" to $updated_list
           #echo "CMS@Home $(echo $f | cut -d/ -f2) $date_s_now" >> $updated_list
         fi
         thestring="CMS@Home $(echo $f | cut -d/ -f2) $(echo $date_s_now | awk '{print $1}')"

         #echo INFO adding 'phys_generator/gridpacks/slc*/*/*' to /cvmfs/cms.cern.ch/.cvmfsdirtab
         # nested stuff
         #grep -q /phys_generator/gridpacks/slc /cvmfs/cms.cern.ch/.cvmfsdirtab
         #if [ $? -ne 0 ] ; then
         #   echo '/phys_generator/gridpacks/slc*/*/*' >> /cvmfs/cms.cern.ch/.cvmfsdirtab
         #fi

         echo INFO publishing $rsync_name
         currdir=$(pwd)
         cd
         time cvmfs_server publish > $HOME/cvmfs_server+publish+CMS_at_HOME_rsync.log 2>&1 # |  tee $HOME/cvmfs_server+publish+CMS_at_HOME_rsync.log
         status=$?
         cd $currdir
         if [ $status -eq 0 ] ; then
            printf "CMS_at_HOME cvmfs_server_publish OK \n$(cat $HOME/cvmfs_server+publish+CMS_at_HOME_rsync.log | sed 's#%#%%#g')\n"
            #printf "CMS_at_HOME cvmfs_server_publish OK \n$(cat $HOME/cvmfs_server+publish+CMS_at_HOME_rsync.log | sed 's#%#%%#g')\n" | mail -s "CMS_at_Home cvmfs_server publish for CMS@Home OK" $notifytowhom
         else
            ( cd ; echo Warning deleting "$thestring" from $updated_list ; cic_del_line "$thestring" $updated_list ; ) ;
            echo ERROR failed cvmfs_server publish
            printf "CMS_at_Home cvmfs_server publish failed\n$(cat $HOME/cvmfs_server+publish+CMS_at_HOME_rsync.log | sed 's#%#%%#g')\n" | mail -s "CMS_at_Home cvmfs_server publish failed" $notifytowhom
            ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
            return 1
         fi
      fi
   else
      echo ERROR failed : rsync -arzuvp $rsync_source $(dirname $rsync_name)
      printf "CMS_at_Home ERROR FAILED: rsync -arzuvp $rsync_source $(dirname $rsync_name)\n" | mail -s "CMS_at_Home ERROR FAILED rsync" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      return 1
   fi
   #
   return 0
}

function check_and_update_siteconf () {

   what="check_and_update_siteconf ()"
   updated_list=/cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates
   rsync_source=$HOME/SITECONF
   #[ $(date +%Y%m%d%H) -lt 2016060102 ] && rsync_source=$HOME/SITECONF_gitlab
   #printf "check_and_update_siteconf () YmdH=$(date +%Y%m%d%H) -lt 2016060102? rsync_sourc=$rsync_source\n" | mail -s "check_and_update_siteconf () Warning rsync_sourc=$rsync_source" $notifytowhom
   rsync_name="/cvmfs/cms.cern.ch/$(basename $rsync_source)"   # /cvmfs/cms.cern.ch/SITECONF
   # FINAL
   #rsync_source=$HOME/SITECONF_gitlab
   #rsync_name="/cvmfs/cms.cern.ch/SITECONF   # /cvmfs/cms.cern.ch/SITECONF

   # update proxy as frequently as possible
   which voms-proxy-info 2>/dev/null 1>/dev/null
   if [ $? -ne 0 ] ; then
      echo Warning attempting to use the LCG-2 UI
      [ -f /afs/cern.ch/cms/LCG/LCG-2/UI/cms_ui_env.sh ] && source /afs/cern.ch/cms/LCG/LCG-2/UI/cms_ui_env.sh
   fi
   export X509_USER_PROXY=$HOME/.florida.t2.proxy
   /usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v srm://srm.ihepa.ufl.edu:8443/srm/v2/server?SFN=/cms/t2/operations/.cmsphedex.proxy  file://$X509_USER_PROXY.copy
   if [ $? -eq 0 ] ; then
      cp $X509_USER_PROXY.copy $X509_USER_PROXY
      voms-proxy-info -all
   else
      printf "check_and_update_siteconf() ERROR failed to download $X509_USER_PROXY\n$(/usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v srm://srm.ihepa.ufl.edu:8443/srm/v2/server?SFN=/cms/t2/operations/.cmsphedex.proxy  file://${X509_USER_PROXY}.copy 2>&1 | sed 's#%#%%#g')n" | mail -s "$what ERROR proxy download failed" $notifytowhom
      return 1
   fi
   if [ ! -f $HOME/.AUTH_TKN ] ; then
      printf "check_and_update_siteconf() ERROR  $HOME/.AUTH_TKN does not exist \n" | mail -s "$what ERROR No Auth Token Found" $notifytowhom
      return 1
   fi
   thelog=$HOME/logs/cvmfs_check_and_update_siteconf.log
   rm -f $thelog
   $HOME/cvmfs_check_and_update_siteconf.sh $rsync_source $HOME/.AUTH_TKN $notifytowhom > $thelog 2>&1
   status=$?
   if [ $status -ne 0 ] ; then
      printf "$what failed  $HOME/cvmfs_check_and_update_siteconf.sh\n$(cat $thelog | sed 's#%#%%#g')\n" | mail -s "ERROR: $what cvmfs_check_and_update_siteconf.sh execution failed" $notifytowhom
      return 1
   fi
   UPDATED_SITES=
   eval $(grep UPDATED_SITES= $thelog 2>/dev/null)
   if [ "x$UPDATED_SITES" == "x" ] ; then
      echo INFO nothing to do thelog=$thelog
      #printf "$what Nothing to update after executing $HOME/cvmfs_check_and_update_siteconf.sh\n$(cat $HOME/cvmfs_check_and_update_siteconf.log | sed 's#%#%%#g')\n" | mail -s "DEBUG : $what cvmfs_check_and_update_siteconf.sh execution shows no updated site" $notifytowhom
      return 0
   fi

   cvmfs_server transaction
   status=$?
   cvmfs_server_transaction_check $status $what
   if [ $? -eq 0 ] ; then
      echo INFO transaction OK for $what
   else
      printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
      cd $currdir
      return 1
   fi
   
   echo rsync -arzuvp ${rsync_source}/SITECONF/ $rsync_name
   #printf "$what rsync -arzuvp ${rsync_source}/SITECONF/ $rsync_name\n" | mail -s "DEBUG : $what rsync" $notifytowhom
   # rsync -arzuvp --delete ${rsync_source}/SITECONF/ $rsync_name > $HOME/cvmfs_check_and_update_siteconf_rsync.log 2>&1
   thelog=$HOME/logs/cvmfs_check_and_update_siteconf_rsync.log 
   rsync -arzuvp ${rsync_source}/SITECONF/ $rsync_name > $thelog 2>&1
   if [ $? -eq 0 ] ; then
      publish_needed=0
      i=0
      #for f in $(grep ^$(basename $rsync_source) $HOME/cvmfs_check_and_update_siteconf_rsync.log | grep -v .git/ 2>/dev/null) ; do
      for f in $(grep ^T[0-9] $thelog | grep -v .git/ 2>/dev/null) ; do
         i=$(expr $i + 1)
         #[ -f "$(dirname $rsync_name)/$f" ] || { echo "[ $i ] " $(dirname $rsync_name)/$f is not a file $publish_needed ; continue ; } ;
         [ -f "$rsync_name/$f" ] || { echo "[ $i ] " $rsync_name/$f is not a file $publish_needed ; continue ; } ;
         publish_needed=1
         echo "[ $i ] " $rsync_name/$f is a file $publish_needed
      done

      echo INFO check point publish_needed $publish_needed

      if [ $publish_needed -eq 0 ] ; then
         echo INFO publish was not needed, So ending the transaction
         ( cd ; cvmfs_server abort -f ; ) ;
         printf "$what publish was not needed, though there are $UPDATED_SITES\nCheck $HOME/logs/cvmfs_check_and_update_siteconf_rsync.log\n$(cat $HOME/logs/cvmfs_check_and_update_siteconf_rsync.log | sed 's#%#%%#g')\nCheck $HOME/logs/cvmfs_check_and_update_siteconf.log\n$(cat $HOME/logs/cvmfs_check_and_update_siteconf.log | sed 's#%#%%#g')\n" | mail -s "ERROR $what publish was not needed but with updated sites" $notifytowhom
      else
         echo INFO publish necessary
         #printf "$what publish is needed UPDATED_SITES=$UPDATED_SITES\nCheck $HOME/cvmfs_check_and_update_siteconf_rsync.log\n$(cat $HOME/cvmfs_check_and_update_siteconf_rsync.log | sed 's#%#%%#g')\nCheck $HOME/cvmfs_check_and_update_siteconf.log\n$(cat $HOME/cvmfs_check_and_update_siteconf.log | sed 's#%#%%#g')\n" | mail -s "DEBUG $what publish is necessary" $notifytowhom
         YMDM=$(date -u +%Y%m%d%H)
         grep "$YMDM " $updated_list | grep -q "$UPDATED_SITES"
         if [ $? -ne 0 ] ; then
            echo $YMDM $(/bin/date +%s) $(/bin/date -u) "$UPDATED_SITES" to $updated_list
            [ $(/bin/hostname -f) == $cvmfs_server_name ] && echo $YMDM $(/bin/date +%s) $(/bin/date -u) "$UPDATED_SITES" >> $updated_list
         fi

         echo INFO publishing $rsync_name
         currdir=$(pwd)
         cd
         time cvmfs_server publish > $HOME/logs/cvmfs_server+publish.log 2>&1
         status=$?
         cd $currdir
         if [ $status -eq 0 ] ; then
            echo "$what cvmfs_server_publish OK"
            #printf "$what cvmfs_server_publish OK UPDATED_SITES=$UPDATED_SITES\nCheck $HOME/cvmfs_check_and_update_siteconf_rsync.log\n$(cat $HOME/cvmfs_check_and_update_siteconf_rsync.log | sed 's#%#%%#g')\nCheck $HOME/cvmfs_check_and_update_siteconf.log\n$(cat $HOME/cvmfs_check_and_update_siteconf.log | sed 's#%#%%#g')\n" | mail -s "DEBUG $what cvmfs_server_publish OK" $notifytowhom
         else
            echo ERROR failed cvmfs_server publish
            printf "$what cvmfs_server_publish failed UPDATED_SITES=$UPDATED_SITES\nCheck $HOME/logs/cvmfs_check_and_update_siteconf_rsync.log\n$(cat $HOME/logs/cvmfs_check_and_update_siteconf_rsync.log | sed 's#%#%%#g')\nCheck $HOME/logs/cvmfs_check_and_update_siteconf.log\n$(cat $HOME/logs/cvmfs_check_and_update_siteconf.log | sed 's#%#%%#g')\n" | mail -s "ERROR $what cvmfs_server_publish failed" $notifytowhom
            ( cd ; cvmfs_server abort -f ; ) ;
            return 1
         fi
      fi
   else
      echo ERROR failed : rsync -arzuvp $rsync_source $(dirname $rsync_name)
      printf "$what FAILED: rsync -arzuvp $rsync_source $(dirname $rsync_name)\n" | mail -s "$what ERROR FAILED rsync" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      return 1
   fi
   #
   return 0
}
####### ENDIN Functions 12345

# crab3
# if no server, install_slc6_crab3 (cron_install_cmssw.sh) -> install_crab3.sh -> rsync.ready
# if server (cron_install_cmssw.sh), work with a particular scram_arch -> rsync ( create soft link for set up files in cmssoft_rsync_slc6.sh ) -> publish
##30    3       *       *       *       cp -r /scratch/shared/* /home/shared/data/
##18 * * * * /home/shared/siteconf/cvmfs_check_siteconf.sh > /home/shared/siteconf/cvmfs_check_siteconf.log 2>&1
16 * * * * $HOME/cron_install_cmssw.sh > $HOME/cron_install_cmssw.log 2>&1
