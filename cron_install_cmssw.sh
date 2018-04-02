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
# 1.8.4: xrootd client to COMP with cmspkg
# 1.8.5: backup_installation and function separation
# version 1.8.5
version=1.8.5

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
if [ "X$(date +%Y%m%d)" == "X20180227" ] ; then
 if [ $(date +%d%H) -ge 2705 -a $(date +%d%H) -lt 2706 ] ; then #
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
cmssws_excluded="CMSSW_4_2_8_SLHCstd_patch1 CMSSW_4_1_3_patch1 CMSSW_4_2_0 CMSSW_4_2_0_pre6 CMSSW_4_2_2_SLHC_pre1 CMSSW_4_2_3_SLHC_pre1 CMSSW_4_2_8_SLHC1_patch1 MSSW_4_2_8_SLHCstd_patch1 CMSSW_4_3_0_pre7 CMSSW_4_4_2_p10JEmalloc CMSSW_5_0_0_g4emtest CMSSW_5_0_0_pre5_root532rc1 CMSSW_4_2_3_onlpatch2 CMSSW_4_2_3_onlpatch4 CMSSW_4_2_7_hinpatch1 CMSSW_4_2_7_onlpatch2 CMSSW_4_2_9_HLT2_onlpatch1 CMSSW_4_4_2_onlpatch1 CMSSW_5_1_0_pre1 CMSSW_5_1_0_pre2 CMSSW_5_2_0_pre2_TS113282 CMSSW_5_2_0_pre3HLT CMSSW_5_3_4_TS125616patch1 CMSSW_5_3_X CMSSW_6_2_X CMSSW_6_2_X_SLHC CMSSW_7_0_X CMSSW_7_1_X CMSSW_7_2_X CMSSW_7_3_X CMSSW_7_4_X CMSSW_7_1_50 CMSSW_10_1_X CMSSW_9_4_MAOD_X CMSSW_9_4_AN_X CMSSW_10_2_X"

updated_list=/cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates
cvmfs_self_mon=/cvmfs/cms.cern.ch/oo77

#slc_vm_machines="slc6+vocms10"
#ssh_key_file=$HOME/.ssh/id_rsa

#release_tag_xml="https://cmssdt.cern.ch/SDT/cgi-bin/ReleasesXML?anytype=1"
releases_map="https://cmssdt.cern.ch/SDT/releases.map"
releases_map_local=$workdir/releases.map
bootstrap_script=http://cmsrep.cern.ch/cmssw/cms/bootstrap.sh
bootstrap_script=http://cmsrep.cern.ch/cmssw/repos/bootstrap-dev.sh # 01FEB2017
bootstrap_script=http://cmsrep.cern.ch/cmssw/repos/bootstrap.sh     # 01FEB2017
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
#cms_common_version_archs="1129+slc6_amd64_gcc530"
cms_common_version_archs="1201+slc6_amd64_gcc630"

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
DOCKER_TAG=cmssw/slc7-installer:cvcms # the one that Shahzad built and pulled from hub

functions=$HOME/functions-cms-cvmfs-mgmt # $workdir/$(basename $0 | sed "s#\.sh##g")-functions # .$(date -u +%s)

#perl -n -e 'print if /^####### BEGIN Functions 12345/ .. /^####### ENDIN Functions 12345/' < $0 | grep -v "Functions 12345" > $functions

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
   date_ymdh=$(date +"["%H"] ["%Y-%m-%d"]")
   printf "$(basename $0) INFO starting $(basename $0)\n" | mail -s "$date_ymdh $(basename $0) starting $(basename $0)" $notifytowhom      
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
  if [ $(ls -al $VO_CMS_SW_DIR/${arch}/external/rpm/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null ; echo $? ; ) -eq 0 ] ; then
     echo INFO "[$j]" arch $arch seems to be already bootstrapped
  else
     echo INFO "[$j]" bootstrapping bootstrap_arch $arch
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
              printf "$(basename $0) $(hostname -f) failed: bootstrap_arch $arch \n$(cat $workdir/logs/bootstrap_arch_slc7_${arch}.log | sed 's#%#%%#g')\n" | mail -s "ERROR $(basename $0) $(hostname -f) bootstrap_arch $arch failed " $notifytowhom
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

     # skip some troublesome releases
     echo $arch | grep -q slc6_amd64_gcc600
     if [ $? -eq 0 ] ; then
        echo $cmssw | grep -q CMSSW_8_1_0_pre[4-8]
        [ $? -eq 0 ] && continue
     fi
     echo $cmssw | grep -q CMSSW_10_0_X
     [ $? -eq 0 ] && continue
     echo $cmssw | grep -q [0-9]_X$
     [ $? -eq 0 ] && { echo Warning $cmssw is excluded so continue ; continue ; } ;
     #echo $arch | grep -q "slc7_amd64_gcc630\|slc7_amd64_gcc530"
     #[ $? -eq 0 ] && { echo $cmssw | grep -q CMSSW_9_1_0_pre3 ; [ $? -eq 0 ] && printf "Warning $0 Skipping CMSSW_9_1_0_pre3 and $arch\n" | mail -s "Warning:Skipping CMSSW_9_1_0_pre3 and $arch" $notifytowhom ; continue ; } ;

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
#echo INFO executing "install_cmssw_aarch64_archs 2>&1 | tee $HOME/logs/cvmfs_install_aarch64.log"
#install_cmssw_aarch64_archs 2>&1 | tee $HOME/logs/cvmfs_install_aarch64.log
echo INFO executing "install_cmssw_centos72_exotic_archs 2>&1 | tee $HOME/logs/install_cmssw_centos72_exotic_archs.log"
install_cmssw_centos72_exotic_archs 2>&1 | tee $HOME/logs/cvmfs_install_cmssw_centos72_exotic_archs.log
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
# [] spacemon-client
echo INFO Next xrootd_client EL6 gcc493 update will be checked and updated as needed
echo
echo INFO installing slc6 gcc493 xrootd_client
install_slc6_amd64_gcc493_xrootd_client
echo
echo INFO Done xrootd_client EL6 gcc493 check and update part of the script
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
#$HOME/cron_rsync_generator_package_from_eos.sh > $HOME/logs/cron_rsync_generator_package_from_eos.log 2>&1
$HOME/cron_rsync_generator_package_from_eos_individual.sh > $HOME/logs/cron_rsync_generator_package_from_eos_individual.log 2>&1
#cms_cvmfs_mgmt_fix_gridpack_perms_cron > $HOME/logs/cms_cvmfs_mgmt_fix_gridpack_perms_cron.log 2>&1
#printf "$(/bin/hostname -f): $(basename $0) \n$(cat $HOME/logs/cms_cvmfs_mgmt_fix_gridpack_perms_cron.log | sed 's#%#%%#g')\n" | mail -s "INFO gridpack_perms fix" $notifytowhom

echo
echo INFO Done cron_rsync_generator_package_from_eos part of the script
echo

# [] pilot config
echo INFO Next Pilot config udate will be checked and updated as needed
$HOME/cvmfs_update_pilot_config.sh 2>&1 | tee $HOME/logs/cvmfs_update_pilot_config.log
echo INFO Done Pilot config check and update part of the script

# [] python
echo INFO Next COMP+python update will be checked and updated as needed
#install_comp_python
install_slc6_amd64_gcc493_comp_python 2>&1 | tee $HOME/logs/install_slc6_amd64_gcc493_comp_python.log
#printf "install_slc6_amd64_gcc493_comp_python\n$(cat $HOME/logs/install_slc6_amd64_gcc493_comp_python.log | sed 's#%#%%#g')\n" | mail -s "INFO: Done install_slc6_amd64_gcc493_comp_python" $notifytowhom      

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
echo INFO Next CA/CRL update
$HOME/update_ca_crl.sh> $HOME/logs/update_ca_crl.log 2>&1
echo INFO Done CA/CRL update

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
time cvmfs_server publish 2>&1 | tee $HOME/logs/cvmfs_server+publish.log
cd $currdir

#backup_installation 2>&1 | tee $HOME/logs/backup_installation.log
#it takes longer than 8 hours: backup_installation_one slc6_amd64_gcc472 2>&1 | tee $HOME/logs/backup_installation_one_slc6_amd64_gcc472.log
echo script $(basename $0) Done
echo
date_ymdh=$(date +"["%H"] ["%Y-%m-%d"]")
printf "$(basename $0) Removing $lock from $(/bin/hostname -f)\n" | mail -s "$date_ymdh $(basename $0) Removing lock" $notifytowhom

rm -f $lock
exit 0


