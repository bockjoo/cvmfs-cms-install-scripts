#!/bin/sh
#
# Bockjoo Kim, U of Florida
# Files
# config file: cron_install_cmssw.config
# ascii DB: /cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates
# lock: cron_install_cmssw.lock
# log location: $HOME/logs
#
# This script is cronized
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
# 1.8.6: Jenkins incorporated, Last Dirty Version
# 1.8.7: Separation of cmssw from this script and put it in functions-cms-cvmfs-mgmt

version=1.8.7

# Basic setups
WORKDIR=/cvmfs/cms.cern.ch
cvmfs_server_yes=yes
workdir=$HOME
CMSSW_REPO=cms
updated_list=/cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates
cvmfs_self_mon=/cvmfs/cms.cern.ch/oo77
export THISDIR=$workdir
export VO_CMS_SW_DIR=$WORKDIR
export LANG="C"
# This machine
which_slc=slc7
# DOCKER TAGS
DOCKER_TAG=cmssw/cc7:amd64
DOCKER_TAG_SLC6=cmssw/slc6:amd64
DOCKER_TAG_SLC8=cmssw/cc8:amd64
functions=$HOME/functions-cms-cvmfs-mgmt # $workdir/$(basename $0 | sed "s#\.sh##g")-functions # .$(date -u +%s)

# Logs and Lock
[ -d $HOME/logs ] || mkdir -p $HOME/logs
lock=$workdir/$(basename $0 | sed "s#\.sh##g").lock

# Parse config
cvmfs_server_name=$(grep cvmfs_server_name= $HOME/cron_install_cmssw.config | grep -v \# | cut -d= -f2)
rpmdb_local_dir=$(grep rpmdb_local_dir= $HOME/cron_install_cmssw.config | grep -v \# | cut -d= -f2)
notifytowhom=$(grep notifytowhom= $HOME/cron_install_cmssw.config | grep -v \# | cut -d= -f2)
theuser=$(/usr/bin/whoami)
jenkins_cmssw=$(grep ^jenkins_cmssw= $HOME/cron_install_cmssw.config | grep -v \# | cut -d= -f2)
cvmfs_server_name=$(eval echo $cvmfs_server_name)
[ "$(/bin/hostname -f)" == "x$cvmfs_server_name" ] || cvmfs_server_yes=no

# Don't let the rpmdb_local_dir be deleted
if [ ! -d $rpmdb_local_dir ] ; then
   mkdir -p $rpmdb_local_dir
   if [ $? -ne 0 ] ; then
      printf "$(basename $0) failed to created rpmdb_local_dir $rpmdb_local_dir\n" | mail -s "ERROR failed to create rpmdb_local_dir" $notifytowhom
      exit 1
   fi
fi
for f in $(find $rpmdb_local_dir -type f -name "*" -print) ; do
   touch $f
done

# Parsed config values
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

# Setup main functions
if [ ! -f $functions ] ; then
   echo ERROR $functions does not exist
   printf "$(basename $0) ERROR failed to create $functions\nfunctions does not exist\n" | mail -s "ERROR failed to create the functions" $notifytowhom
   exit 1
fi

source $functions

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

diff $updated_list $HOME/$(basename $updated_list) 1>/dev/null 2>/dev/null
if [ $? -ne 0 ] ; then
      printf "$(basename $0) Something updated $updated_list\n$(diff $updated_list $HOME/$(basename $updated_list))\n" | mail -s "$(basename $0) WARN $(basename $updated_list) updated" $notifytowhom      
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

# [1] gridpacks still active in cron: Documentation README.gridpacks
echo INFO Execute only the first half of the even hours
echo INFO Next cron_rsync_generator_package_from_eos as needed
echo
$HOME/cron_rsync_generator_package_from_eos_individual.sh > $HOME/logs/cron_rsync_generator_package_from_eos_individual.log 2>&1
echo
echo INFO Done cron_rsync_generator_package_from_eos part of the script
echo

# [2] siteconf still active in cron
echo INFO Next cvmfs_check_and_update_siteconf.sh using gitlab and cric
echo
$HOME/cvmfs_check_and_update_siteconf.sh > $HOME/logs/cvmfs_check_and_update_siteconf.log 2>&1
echo INFO Done cvmfs_check_and_update_siteconf.sh using gitlab
echo

# [3] install cmssw: In Jenkins but it's here just in case
echo INFO "executing run_install_cmssw > $HOME/logs/run_install_cmssw.log 2>&1"
run_install_cmssw > $HOME/logs/run_install_cmssw.log 2>&1

# [] install power arch
echo INFO "executing install_cmssw_power_archs 2>&1 | tee  $HOME/logs/install_cmssw_power_archs.log"
install_cmssw_power_archs 2>&1 | tee  $HOME/logs/install_cmssw_power_archs.log

# [] install slc aarch
echo INFO executing "install_cmssw_centos72_exotic_archs 2>&1 | tee $HOME/logs/install_cmssw_centos72_exotic_archs.log"
install_cmssw_centos72_exotic_archs 2>&1 | tee $HOME/logs/cvmfs_install_cmssw_centos72_exotic_archs.log
echo
echo INFO Done CMSSW installation part of the script


if [ ] ; then
# [] CRAB3
echo INFO Next CRAB3 EL6 gcc493 update will be checked and updated as needed
echo
echo INFO installing slc6 gcc493 crab3
#install_slc6_amd64_gcc493_crab3 > $HOME/logs/install_slc6_amd64_gcc493_crab3.log 2>&1
docker_install_crab3 slc6_amd64_gcc493 > $HOME/logs/install_slc6_amd64_gcc493_crab3.log 2>&1
echo
echo INFO Done CRAB3 EL6 gcc493 check and update part of the script
echo
fi # if [ ] ; then

# [] Rucio Client on Jenkins
Maintenance_Ymd=20200130
Maintenance_d=$(echo $Maintenance_Ymd | cut -c7-8)
Maintenance_H1=11
Maintenance_H2=12
if [ "X$(date +%Y%m%d)" == "X${Maintenance_Ymd}" ] ; then
 echo it is one echo $(date +%d%H) -ge ${Maintenance_d}${Maintenance_H1} -a $(date +%d%H) -lt ${Maintenance_d}${Maintenance_H2}
 if [ $(date +%d%H) -ge ${Maintenance_d}${Maintenance_H1} -a $(date +%d%H) -lt ${Maintenance_d}${Maintenance_H2} ] ; then
    echo INFO Next Rucio Client
    echo
    $HOME/install_rucio_client.sh 2>&1 | tee $HOME/logs/install_rucio_client.log
    echo
    echo INFO Done Next Rucio Client
    echo
 fi
fi

if [ ] ; then
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
fi # if [ ] ; then


echo INFO Next LHAPDF update will be checked and updated as needed
echo

# [] lhapdf still active in cron
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


if [ ] ; then
# disabled because
# cvmfs_update_pilot_config.sh ERROR at /home/cvcms/tmp/kestrel/src kestrel_pilot_config --write -o /home/cvcms/tmp/config_generated.ini failed
# Traceback (most recent call last):
#   File "./kestrel_pilot_config", line 8, in <module>
#     import classad
# ImportError: libpython2.6.so.1.0: cannot open shared object file: No such file or directory
#
# [] pilot config
echo INFO Next Pilot config udate will be checked and updated as needed
$HOME/cvmfs_update_pilot_config.sh 2>&1 | tee $HOME/logs/cvmfs_update_pilot_config.log
echo INFO Done Pilot config check and update part of the script
fi # if [ ] ; then

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
RUN_WHEN=02
if [ "x$THEHOUR" == "x$RUN_WHEN" ] ; then
      echo INFO executing $HOME/cvmfs_update_cmssw_git_mirror_v3.sh
      $HOME/cvmfs_update_cmssw_git_mirror_v3.sh > $HOME/logs/cvmfs_update_cmssw_git_mirror.log 2>&1 &
      theps=$!
      i=0
      while : ; do
            #echo DEBUG $i seconds $(ps auxwww | grep -v grep | awk '{print "+"$2"+"}' | grep "+${theps}+")
            [ $(ps auxwww | grep -v grep | awk '{print "+"$2"+"}' | grep -q "+${theps}+" ; echo $?) -eq 0 ] || break
            if [ $i -gt 3600 ] ; then
               ps auxwww | grep -v grep | awk '{print "+"$2"+"}' | grep -q "+${theps}+"
               if [ $? -eq 0 ] ; then
                  git_pses=$(pstree -a -l -p $theps | grep \\-git | cut -d, -f2 | awk '{print $1}')
                  kill $git_pses
               fi # && kill $theps # FIXME kill git processes instead of the parent.
               #echo DEBUG timeout reached. Breaking...
               break
            fi
            #echo DEBUG $i seconds passed. pstree follows for FIXME kill git processes instead of the parent.
            #pstree -alp $theps
            i=$(expr $i + 1)
            sleep 1
      done
      wait $theps
      echo INFO status of cvmfs_update_cmssw_git_mirror_v3.sh execution : $?
fi
echo INFO Done git mirror check
# Check Point 5
#rm -f $lock
#exit 0
#fi # if [ ] ; then

# [] The host's CA/CRL update for grid operations still active in cron
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

if [ ] ; then
echo INFO Next CRAB3 EL7 gcc630 update will be checked and updated as needed
echo
echo INFO installing slc7 gcc630 crab3
install_slc7_amd64_gcc630_crab3 > $HOME/logs/install_slc7_amd64_gcc630_crab3.log 2>&1
echo
echo INFO Done CRAB3 EL7 gcc630 check and update part of the script
fi # if [ ] ; then

#backup_installation 2>&1 | tee $HOME/logs/backup_installation.log
#it takes longer than 8 hours: backup_installation_one slc6_amd64_gcc472 2>&1 | tee $HOME/logs/backup_installation_one_slc6_amd64_gcc472.log
cp $updated_list $HOME/
echo script $(basename $0) Done
echo
date_ymdh=$(date +"["%H"] ["%Y-%m-%d"]")
printf "$(basename $0) Removing $lock from $(/bin/hostname -f)\n" | mail -s "$date_ymdh $(basename $0) Removing lock" $notifytowhom

rm -f $lock
exit 0


