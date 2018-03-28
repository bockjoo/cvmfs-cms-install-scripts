#!/bin/bash
# versiono 0.1.7
version=0.1.7
source $HOME/cron_install_cmssw.config # notifytowhom
updated_list=/cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates

#
# Use the one that is created by create_host_proxy_download_siteconf.sh
# If timeleft is not sufficient, create one
#
#x509cert=$HOME/CERTS/cvmfs.ihepa.ufl.edu/hostcert.pem
#x509certkey=$HOME/CERTS/cvmfs.ihepa.ufl.edu/hostkey.pem
#x509proxyvalid="168:30"
#export X509_USER_PROXY=$HOME/.cvmfs.host.proxy
export X509_USER_PROXY=$HOME/.florida.t2.proxy

# initial values:
export EOS_MGM_URL="root://eoscms.cern.ch"
#TOTAL_RSYNC_SIZE_LIMIT=100 # in Gigabytes
TOTAL_RSYNC_SIZE_LIMIT=150 # in Gigabytes 29APR2015
INDIVIDUAL_RSYNC_SIZE_LIMIT=5 # in Gigabytes
#$(ls -al /afs/cern.ch/project/eos/installation/cms | awk '{print $NF}')
#EOS_CLIENT_VERSION=${EOS_CLIENT_VERSION:-$(ls -al /afs/cern.ch/project/eos/installation/cms 2>/dev/null | awk '{print $NF}')}
#EOS_CLIENT_VERSION=${EOS_CLIENT_VERSION:-0.3.4}
EOS_CLIENT_VERSION=${EOS_CLIENT_VERSION:-0.3.15}
#EOS_CLIENT_VERSION=${EOS_CLIENT_VERSION:-0.3.35}
#alias eos='/afs/cern.ch/project/eos/installation/0.3.15/bin/eos.select'
#alias eoscms='eos'
#alias eosforceumount='killall eosfsd 2>/dev/null; killall -9 eosfsd 2>/dev/null; fusermount -u '
#alias eosmount='/afs/cern.ch/project/eos/installation/0.3.15/bin/eos.select -b fuse mount'
#alias eosumount='/afs/cern.ch/project/eos/installation/0.3.15/bin/eos.select -b fuse umount'
export EOSSYS=/home/cvcms/eos_installation/${EOS_CLIENT_VERSION}
#export EOSSYS=/afs/cern.ch/project/eos/installation/${EOS_CLIENT_VERSION}

function higher_priority_gridpacks () {
printf "
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_s-channel-M400_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_s-channel-M500_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_s-channel-M800_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_s-channel-M1200_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_t-channel-M500_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_t-channel-M1200_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_t-channel-M1500_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_pair-M400_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_pair-M500_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_pair-M600_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_pair-M800_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_pair-M900_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_pair-M1200_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_pair-M1500_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/2017/13TeV/madgraph/V5_2.6.0/SingleLQ3ToTauB_5f/SingleLQ3ToTauB_5f_madgraph_LO_pair-M2000_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/slc6_amd64_gcc481/13TeV/madgraph/V5_2.3.3/ggh01_M125_Toa01a01_M50_Totautautautau/v1/ggh01_M125_Toa01a01_M50_Totautautautau_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/slc6_amd64_gcc481/13TeV/madgraph/V5_2.3.3/LLJJ_aTGC_EWK_SM_5f_LO/LLJJ_aTGC_EWK_SM_5f_LO_tarball-fixedMadspinCard_V1.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/slc6_amd64_gcc481/13TeV/madgraph/V5_2.3.3/ChargedHiggs_GMmodel_HToWZ/SinglyChargedHiggsGMmodel_HWZ_M500_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/slc6_amd64_gcc481/13TeV/madgraph/V5_2.3.3/ChargedHiggs_GMmodel_HToWZ/SinglyChargedHiggsGMmodel_HWZ_M500_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/slc6_amd64_gcc481/13TeV/madgraph/V5_2.3.3/ggh01_M125_Toa01a01_M25_Tomumubb/v2/ggh01_M125_Toa01a01_M25_Tomumubb_tarball.tar.xz
/eos/cms/store/group/phys_generator/cvmfs/gridpacks/slc6_amd64_gcc481/13TeV/madgraph/V5_2.3.3/ggh01_M125_Toa01a01_M30_Tomumubb/v2/ggh01_M125_Toa01a01_M30_Tomumubb_tarball.tar.xz\n"

}

function eos () {
  $EOSSYS/bin/eos.select
  return $?
}

function eoscms () {
  $EOSSYS/bin/eos.select
  return $?
}

function eosforceumount () {
  killall eosfsd 2>/dev/null
  killall -9 eosfsd 2>/dev/null
  fusermount -u $1
  return $?
}

#function eosmount () {
#  $EOSSYS/bin/eos.select -b fuse mount $1
#  return $?  
#}

#function eosumount () {
#  $EOSSYS/bin/eos.select -b fuse umount $1
#  return $?
#}



function cic_sed_del_line () { # func description: It deletes a line                     
  if [ $# -lt 2 ] ; then
     echo ERROR cic_sed_del_line string file
     return 1
  fi
  string=$1
  infile=$2
  sed -i "/$(echo $string | sed 's^/^\\\/^g')/ d" $infile
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

:
: #########  $0       ###################################################
:

# On DEC 16, 2014, I realized I need the grid proxy to mount eos personally
echo INFO X509_USER_PROXY $X509_USER_PROXY
echo INFO executing voms-proxy-info -timeleft
voms-proxy-info -timeleft 2>&1
#/usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v srm://srm.ihepa.ufl.edu:8443/srm/v2/server?SFN=/cms/t2/operations/.cmsphedex.proxy  file://$X509_USER_PROXY.copy
#if [ $? -eq 0 ] ; then
#   cp $X509_USER_PROXY.copy $X509_USER_PROXY
#   voms-proxy-info -all
#else
#   printf "$(basename $0) ERROR failed to download $X509_USER_PROXY\n$(/usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v srm://srm.ihepa.ufl.edu:8443/srm/v2/server?SFN=/cms/t2/operations/.cmsphedex.proxy  file://${X509_USER_PROXY}.copy 2>&1 | sed 's#%#%%#g')n" | mail -s "$(basename $0) ERROR proxy download failed" $notifytowhom
#fi
#/usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v srm://srm.ihepa.ufl.edu:8443/srm/v2/server?SFN=/cms/t2/operations/.cmsphedex.proxy  file://$X509_USER_PROXY.copy
/usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v gsiftp://cmsio.rc.ufl.edu/cms/t2/operations/.cmsphedex.proxy  file://$X509_USER_PROXY.copy
if [ $? -eq 0 ] ; then
   cp $X509_USER_PROXY.copy $X509_USER_PROXY
      voms-proxy-info -all
else
      printf "$(basename $0) ERROR failed to download $X509_USER_PROXY\n$(/usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v gsiftp://cmsio.rc.ufl.edu/cms/t2/operations/.cmsphedex.proxy  file://${X509_USER_PROXY}.copy 2>&1 | sed 's#%#%%#g')n" | mail -s "$(basename $0) ERROR proxy download failed" $notifytowhom
fi

timeleft=$(voms-proxy-info -timeleft 2>/dev/null)
if [ $timeleft -lt 1900 ] ; then # 1800 + 100
   #/usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v srm://srm.ihepa.ufl.edu:8443/srm/v2/server?SFN=/cms/t2/operations/.cmsphedex.proxy  file://$X509_USER_PROXY
   /usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v gsiftp://cmsio.rc.ufl.edu/cms/t2/operations/.cmsphedex.proxy  file://$X509_USER_PROXY.copy
   [ $? -eq 0 ] && cp $X509_USER_PROXY.copy $X509_USER_PROXY
if [ ] ; then
   echo INFO creating the grid proxy
   voms-proxy-init -cert $x509cert -key $x509certkey -out $X509_USER_PROXY -valid ${x509proxyvalid} 2>&1
   if [ $? -ne 0 ] ; then
      printf "$(basename $0) ERROR voms-proxy-init failed\n" | mail -s "$(basename $0) ERROR voms-proxy-init failed" $notifytowhom
      exit 1
   fi
fi
   timeleft=$(voms-proxy-info -timeleft 2>/dev/null)
fi

echo INFO proxy timeleft $timeleft


#
# Limit frequency of the execution
#
# Execute only during the first half of the even hours
# Execute only every five hours
#[ $(expr $(date +%H) % 5 ) -eq 0 ] || { echo INFO Execute only every five hours ; exit 0 ; } ;
#[ $(date +%M) -lt 30 ] || { echo INFO Execute only the first half of the even hours ; exit 0 ; } ;

rsync_source="$HOME/eos2/cms/store/group/phys_generator/cvmfs/gridpacks"
rsync_name="/cvmfs/cms.cern.ch/phys_generator/gridpacks"
rsync_destination="/cvmfs/cms.cern.ch/phys_generator/gridpacks"

echo INFO Checking mounting eos

ls $HOME/eos2 | grep "Bad address" | grep -q "cannot access"
if [ $? -eq 0 ] ; then
   echo Warning $HOME/eos2 is not properly mounted
   ls $HOME/eos2
   echo Warning eosforceumount $HOME/eos2
   eosforceumount $HOME/eos2
fi

df -h | grep -q $(echo $EOS_MGM_URL | cut -d/ -f3 | cut -d: -f1)
if [ $? -eq 0 ] ; then
   echo INFO $HOME/eos2 is already mounted
else
   $EOSSYS/bin/eos.select -b fuse mount $HOME/eos2
fi

if [ ! -d $rsync_source ] ; then
   echo ERROR rsync_source not found eosmount error
   printf "$(basename $0) $rsync_source not found \n Issue with: $EOSSYS/bin/eos.select -b fuse mount $HOME/eos2 did not work\nls $HOME/eos2/cms follows\n$(ls $HOME/eos2/cms)\ntail -10 eos log\n$(tail -10 /tmp/eos*)" | mail -s "$(basename $0) ERROR $EOSSYS/bin/eos.select -b fuse mount $HOME/eos2 failed " $notifytowhom
   $EOSSYS/bin/eos.select -b fuse umount $HOME/eos2
   ps auxwww | grep -v grep | grep -q eosfsd
   if [ $? -eq 0 ] ; then
      echo Warning eosforceumount $HOME/eos2
      eosforceumount $HOME/eos2
   fi
   ls $HOME/eos2
   exit 1
fi

echo INFO looks good $rsync_source exists

TOTAL_RSYNC_SIZE=$(/usr/bin/du -s $rsync_source | awk '{print $1}')
TOTAL_RSYNC_SIZE=$(echo "scale=2 ; $TOTAL_RSYNC_SIZE / 1024 / 1024" | bc | cut -d. -f1)
[ "x$TOTAL_RSYNC_SIZE" == "x" ] && TOTAL_RSYNC_SIZE=0
if [ $TOTAL_RSYNC_SIZE -gt $TOTAL_RSYNC_SIZE_LIMIT ] ; then
   echo Warning TOTAL RSYNC SIZE is too large
   #printf "$(basename $0) Warning TOTAL_RSYNC_SIZE > TOTAL_RSYNC_SIZE_LIMIT : $TOTAL_RSYNC_SIZE > $TOTAL_RSYNC_SIZE_LIMIT \n Will not rsync $rsync_source" | mail -s "$(basename $0) Warning ERROR TOTAL_RSYNC_SIZE > TOTAL_RSYNC_SIZE_LIMIT" $notifytowhom
fi

echo INFO looks good TOTAL_RSYNC_SIZE "<" TOTAL_RSYNC_SIZE_LIMIT

# Check Point 1
#echo rsync -arzuvp --delete $rsync_source $(dirname $rsync_name)
#exit 0
cvmfs_server list  | grep stratum0 | grep -q transaction
if [ $? -eq 0 ] ; then
   #if [ ! -f $lock ] ; then
   #   echo INFO $lock does not exist
      #need_to_fix_mount_issue=2
      #printf "$(basename $0) cvmfs mount issue\n$lock does not exist\ncvmfs_server list\n$(cvmfs_server list)\n" | mail -s "$(basename $0) needs to fix the mount issue" $notifytowhom
   echo ERROR cvmfs server already in transaction
   exit 1
   #fi
fi

echo INFO Doing cvmfs_server transaction
cvmfs_server transaction
status=$?
what="$(basename $0)"
cvmfs_server_transaction_check $status $what
if [ $? -eq 0 ] ; then
   echo INFO transaction OK for $what
else
   echo ERROR transaction check FAILED
   printf "$(basename $0): 1 cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
   $EOSSYS/bin/eos.select -b fuse umount $HOME/eos2
   ps auxwww | grep -v grep | grep -q eosfsd
   if [ $? -eq 0 ] ; then
      echo Warning eosforceumount $HOME/eos2
      eosforceumount $HOME/eos2
   fi
   ls $HOME/eos2
   exit 1
fi

echo DEBUG check point will execute to see if the update is necessary for individual files 
#echo rsync -arzuvp $rsync_source $(dirname $rsync_name)
#rm -f $HOME/rsync+generator+package+from+eos.log
#rsync -arzuvp $rsync_source $(dirname $rsync_name) 2>&1 | tee $HOME/rsync+generator+package+from+eos.log
echo rsync -arzuvp --delete --dry-run $rsync_source $(dirname $rsync_name)
#echo rsync -arzuvp $rsync_source $(dirname $rsync_name)
thelog=$HOME/logs/rsync+generator+package+from+eos.log
rm -f $thelog
rsync -arzuvp --delete --dry-run $rsync_source $(dirname $rsync_name) > $thelog 2>&1
#rsync -arzuvp $rsync_source $(dirname $rsync_name) > $thelog 2>&1
status=$?
echo INFO for now aborting the rsync to rsync only those files that are new
( cd ; cvmfs_server abort -f ; ) ;
NGRIDPACKS=120
NEWGRIDPACKS_ONLY= # NEWGRIDPACKS_ONLY=1
#echo INFO gridpakcs to be rsynced: $(grep "tar.xz\|tar.gz\|tgz" $thelog | grep "^gridpacks/" | wc -l)
echo INFO gridpakcs to be rsynced: $(grep "tar.xz\|tar.gz\|tgz" $thelog | grep "^gridpacks/" | grep -v "_noiter" | wc -l)

cvmfs_server transaction
status=$?
what="$(basename $0)"
cvmfs_server_transaction_check $status $what
if [ $? -eq 0 ] ; then
   echo INFO transaction OK for $what
else
   echo ERROR transaction check FAILED
   ( cd ; cvmfs_server abort -f ; ) ;
   printf "$(basename $0): 2 cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
   $EOSSYS/bin/eos.select -b fuse umount $HOME/eos2
   ps auxwww | grep -v grep | grep -q eosfsd
   if [ $? -eq 0 ] ; then
      echo Warning eosforceumount $HOME/eos2
      eosforceumount $HOME/eos2
   fi
   ls $HOME/eos2
   exit 1
fi

source $HOME/functions-cms-cvmfs-mgmt

#cat $thelog
if [ $status -eq 0 ] ; then
   i=0
   publish_needed=0
   # First delete files/directories that are not on EOS anymore
   THOSE_FILES_DELETED=
   ndeletions=$(for f in $(grep ^"deleting gridpacks/" $thelog 2>/dev/null | awk '{print $NF}' | grep gridpacks/ | grep -v /.cvmfscatalog) ; do echo $f ; done | wc -l)
   for f in $(grep ^"deleting gridpacks/" $thelog 2>/dev/null | awk '{print $NF}' | grep gridpacks/ | grep -v /.cvmfscatalog) ; do
       thefile=$(dirname $rsync_name)/$f
       echo $thefile | grep -q cvmfscatalog
       [ $? -eq 0 ] && continue
       i=$(expr $i + 1)
       [ $i -gt $NGRIDPACKS ] && break
       #echo INFO removing $thefile
       if [ -f "$thefile" ] ; then
        ( cd $(dirname $thefile)
          pwd | grep -q /cvmfs/cms.cern.ch/phys_generator/gridpacks
          if [ $? -eq 0 ] ; then
             echo INFO rm -rf $(basename  $thefile) at $(pwd)
             rm -rf $(basename  $thefile)
             #THOSE_FILES_DELETED="$THOSE_FILES_DELETED $thefile"
             #else
             #THOSE_FILES_DELETED="$THOSE_FILES_DELETED $(pwd)_does_not_have_/cvmfs/cms.cern.ch/phys_generator/gridpacks"
          fi
        )
        THOSE_FILES_DELETED="$THOSE_FILES_DELETED $thefile"
        publish_needed=1
       fi
   done
   if [ $publish_needed -eq 1 ] ; then
      time cvmfs_server publish > $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos_individual_delete.log 2>&1
      cvmfs_server transaction
      #publish_needed=0
      printf "$(basename $0) INFO $NGRIDPACKS / $ndeletions are deleted from /cvms/cms.cern.ch\nNFILES=$(echo $THOSE_FILES_DELETED | wc -w)\n$(for f in $THOSE_FILES_DELETED ; do echo $f ; done)\n" | mail -s "$(basename $0) INFO files deleted" $notifytowhom
  fi
   files_with_strange_permission=""
   destfiles=""
   i=0
   publish_needed=0
   grep "tar.xz\|tar.gz\|tgz" $thelog | grep "^gridpacks/" | grep -v "_noiter" | grep -v "sys.v\|sys.a" > $HOME/logs/gridpacks_schedule.txt
   #
   # New ones first and the update later 
   # 
   #for f in $(grep ^$(basename $rsync_source) $thelog 2>/dev/null | grep -v "/.sys.v#\|/.sys.a#" | grep -v /$) ; do
   cms_cvmfs_check_gridpacks_diff 2>/dev/null | grep "^1 " | awk '{print $NF}' | sed "s#$(dirname $rsync_source)# #g" | awk '{print $NF}'  > $HOME/logs/gridpacks_normal_priority.txt
   rm -f $HOME/logs/gridpacks_high_priority.txt
   touch $HOME/logs/gridpacks_high_priority.txt
   for gridpack in $(higher_priority_gridpacks  | sed "s#/eos/cms/store/group/phys_generator/cvmfs/gridpacks/# gridpacks/#g" | awk '{print $NF}') ; do
       grep -q $gridpack $HOME/logs/gridpacks_normal_priority.txt
       [ $? -eq 0 ] || continue # its not in the rsync list it is already in the cvmfs
       sed -i "/$(echo $gridpack | sed 's^/^\\\/^g')/ d" $HOME/logs/gridpacks_normal_priority.txt
       echo $gridpack >> $HOME/logs/gridpacks_high_priority.txt
   done
   UPDATED_GRIDPACKS=
   for f in $(cat $HOME/logs/gridpacks_high_priority.txt) $(cms_cvmfs_check_gridpacks_diff 2>/dev/null | grep "^2 \|^3 \|^4" | awk '{print $NF}' | sed "s#$(dirname $rsync_source)/# #g" | awk '{print $NF}') $(cat $HOME/logs/gridpacks_normal_priority.txt) ; do
      # 
      # rsync_source="$HOME/eos2/cms/store/group/phys_generator/cvmfs/gridpacks"
      # rsync_name="/cvmfs/cms.cern.ch/phys_generator/gridpacks"
      # f is in the form gridpacks/slc6_amd64_gcc481/13TeV/madgraph/V5_2.2.2/exo_DMDiJet/v3/DMSpin0_scalar_ggPhibb1j_g1_v2_150_5_805_tarball.tar.xz
      #[ -f "$(dirname $rsync_source)/$f" ] || { echo "[ $i ] " $(dirname $rsync_source)/$f is not a file $publish_needed ; continue ; } ;
      [ -f "$(dirname $rsync_source)/$f" ] || continue
      publish_needed=1
      destfile=$(dirname $rsync_name)/$f # in the form /cvmfs/cms.cern.ch/phys_generator/gridpacks/slc6_amd64_gcc481/13TeV/madgraph/V5_2.2.2/exo_DMDiJet/v3/DMSpin0_scalar_ggPhibb1j_g1_v2_150_5_805_tarball.tar.xz
      destfiles="$destfiles $destfile"
      if [ ! -d $(dirname $destfile) ] ; then
         echo INFO creating $(dirname $destfile) #>> $thelog 2>&1
         mkdir -p $(dirname $destfile) > $HOME/logs/eos_mkdir_log 2>&1
         grep -q "File exists" $HOME/logs/eos_mkdir_log
         if [ $? -eq 0 ] ; then
            if [ -f $(dirname $destfile) ] ; then
               rm -rf $(dirname $destfile)
               printf "$(basename $0) ERROR failed: $(dirname $destfile) supposed to be a directory. Something went wrong\n" | mail -s "$(basename $0) ERROR failed: mkdir -p $(dirname $destfile) " $notifytowhom
               #echo DRY rm -rf $(dirname $destfile)
               time cvmfs_server publish > $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos.log 2>&1
               [ $? -eq 0 ] ||  ( cd ; cvmfs_server abort -f ; ) ;
               echo INFO eosumount $HOME/eos2
               $EOSSYS/bin/eos.select -b fuse umount $HOME/eos2
               ps auxwww | grep -v grep | grep -q eosfsd
               if [ $? -eq 0 ] ; then
                  echo Warning eosforceumount $HOME/eos2
                  eosforceumount $HOME/eos2
               fi
               echo INFO checking with ls $HOME/eos2
               ls $HOME/eos2
               echo script $0 Done
               log=$HOME/logs/$(basename $0 | sed 's#\.sh#\.log#g')
               eos_fuse_logs=
               for f in /tmp/eos-fuse.*.log ; do
                  [ -f "$f" ] && { eos_fuse_logs="$eos_fuse_logs $f" ; rm -f $f ; } ;
               done
               exit 1
            fi
         fi
      fi
      if [ ! -f $(dirname $rsync_source)/$f ] ; then
           echo Warning $(dirname $rsync_source)/$f does not exist. Maybe, it is deleted 
           #publish_needed=1
           continue
      fi
      # To upload new files only
      echo DEBUG  NEWGRIDPACKS_ONLY=$NEWGRIDPACKS_ONLY
      if [ $NEWGRIDPACKS_ONLY ] ; then
      if [ -f $destfile ] ; then
         echo INFO NEWGRIDPACKS_ONLY=$NEWGRIDPACKS_ONLY: $destfile exists so continue
         #echo DEBUG checking $(dirname $rsync_source)/$f
         #ls -al $(dirname $rsync_source)/$f
         #echo DEBUG checking $(dirname $rsync_name)/$f
         #ls -al $(dirname $rsync_name)/$f
         #echo DEBUG $destfile exists
         continue
      fi
      # To upload new files only 
      fi # if [  ] ; then
      #echo DEBUG checking $(dirname $rsync_source)/$f
      #ls -al $(dirname $rsync_source)/$f
      #echo DEBUG checking $(dirname $rsync_name)/$f
      #ls -al $(dirname $rsync_name)/$f
      echo INFO individual rsync : rsync -arzuvp --delete $(dirname $rsync_source)/$f $(dirname $destfile)
      rsync -arzuvp --delete $(dirname $rsync_source)/$f $(dirname $destfile) 2>&1
      if [ $? -ne 0 ] ; then
         printf "$(basename $0) ERROR failed: rsync -arzuvp --delete $(dirname $rsync_source)/$f $(dirname $destfile)\n"
         printf "$(basename $0) ERROR failed: rsync -arzuvp --delete $(dirname $rsync_source)/$f $(dirname $destfile)\n" | mail -s "$(basename $0) ERROR failed: rsync" $notifytowhom
         continue
      fi
       
      #if [ $(echo $(ls -al $(dirname $rsync_source)/$f | awk '{print $5}')) -ne $(echo $(ls -al $destfile | awk '{print $5}')) ] ; then
      #   echo ERROR $(dirname $rsync_source)/$f and $destfile are different after rsync. $destfile removed
      #   rm -f $destfile
      #   printf "$(basename $0) ERROR failed: $(dirname $rsync_source)/$f and $destfile are different after rsync $destfile removed \n$(ls -al $(dirname $rsync_source)/$f)\n$(ls -al $destfile)" | mail -s "$(basename $0) ERROR failed: rsync II" $notifytowhom
      #   continue
      #fi

      i=$(expr $i + 1)
      echo "[ $i ] " $(dirname $rsync_name)/$f is a file $publish_needed
      INDIVIDUAL_RSYNC_SIZE=$(/usr/bin/du -s $(dirname $rsync_name)/$f | awk '{print $1}')
      INDIVIDUAL_RSYNC_SIZE=$(echo "scale=2 ; $INDIVIDUAL_RSYNC_SIZE / 1024 / 1024" | bc | cut -d. -f1)
      [ "x$INDIVIDUAL_RSYNC_SIZE" == "x" ] && INDIVIDUAL_RSYNC_SIZE=0
      if [ $INDIVIDUAL_RSYNC_SIZE -gt $INDIVIDUAL_RSYNC_SIZE_LIMIT ] ; then
         echo Warning INDIVIDUAL_RSYNC_SIZE -gt INDIVIDUAL_RSYNC_SIZE_LIMIT $INDIVIDUAL_RSYNC_SIZE -gt $INDIVIDUAL_RSYNC_SIZE_LIMIT
         printf "$(basename $0) Warning INDIVIDUAL_RSYNC_SIZE > INDIVIDUAL_RSYNC_SIZE_LIMIT : $INDIVIDUAL_RSYNC_SIZE > $INDIVIDUAL_RSYNC_SIZE_LIMIT $(dirname $rsync_name)/$f \n Will not publish the rsync result" | mail -s "$(basename $0) Warning INDIVIDUAL_RSYNC_SIZE > INDIVIDUAL_RSYNC_SIZE_LIMIT" $notifytowhom
      fi
      ## begin DRY
      #publish_needed=0
      #continue
      ## end DRY
      themode=$(/usr/bin/stat -c %a $(dirname $rsync_name)/$f)
      original_file=$(echo $(dirname $rsync_name)/$f | sed "s#$rsync_name#$rsync_source#")
      original_mode=$(/usr/bin/stat -c %a $original_file)
      original_user=$(/usr/bin/stat -c %U $original_file)
      if [ $themode -lt 400 ] ; then
         theuser=$(/usr/bin/stat -c %U $(dirname $rsync_name)/$f)
         files_with_strange_permission="$files_with_strange_permission ${original_mode}+${original_user}+${themode}+${theuser}+$(dirname $rsync_name)/${f}"
      fi
      if [ $(echo $themode | cut -c2-) -lt 40 ] ; then
         theuser=$(/usr/bin/stat -c %U $(dirname $rsync_name)/$f)
         echo "$files_with_strange_permission" | grep -q "+$(dirname $rsync_name)/$f" || files_with_strange_permission="$files_with_strange_permission ${original_mode}+${original_user}+${themode}+${theuser}+$(dirname $rsync_name)/$f"
      fi
      if [ $(echo $themode | cut -c3-) -lt 4 ] ; then
         theuser=$(/usr/bin/stat -c %U $(dirname $rsync_name)/$f)
         #files_with_strange_permission="$files_with_strange_permission ${original_mode}+${original_user}+${themode}+${theuser}+$(dirname $rsync_name)/$f"
         echo "$files_with_strange_permission" | grep -q "+$(dirname $rsync_name)/$f" || files_with_strange_permission="$files_with_strange_permission ${original_mode}+${original_user}+${themode}+${theuser}+$(dirname $rsync_name)/$f"
      fi
      #time cvmfs_server publish > $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos_individual.log 2>&1
      if [ $publish_needed -eq 1 ] ; then
         #echo INFO doing cvmfs_server publish for $(dirname $rsync_source)/$f $(dirname $destfile)/$(basename $f)
         #time cvmfs_server publish > $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos_individual.log 2>&1
         #cvmfs_server transaction
         #publish_needed=0
         [ $i -gt $NGRIDPACKS ] && break
      fi
      UPDATED_GRIDPACKS="$UPDATED_GRIDPACKS $f"
   done
   #if [ $publish_needed -eq 1 ] ; then
   #   cvmfs_server transaction
   #fi
   if [ "x$files_with_strange_permission" != "x" ] ; then
         printout=$(printf "$(basename $0) Found files with strange permsion\n$(for f in $files_with_strange_permission ; do echo $f ; done)\n")
         for f in $files_with_strange_permission ; do
           thefile=$(echo $f | sed 's#+# #g' | awk '{print $NF}')
           chmod 644 $thefile
         done
         printf "$printout\nStrange files after changing the perm\n$(for f in $files_with_strange_permission ; do ls -al $(echo $f | cut -d+ -f5-) ; done)\n" | mail -s "$(basename $0) Warning Found files with strange permsion" $notifytowhom
   fi
   if [ "x$destfiles" != "x" ] ; then
      printf "$(basename $0) INFO added files\n$(for f in $destfiles ; do echo $f ; done)\n" | mail -s "$(basename $0) INFO gridpack added" $notifytowhom
   fi
   echo INFO check point publish_needed $publish_needed

   if [ $publish_needed -eq 0 ] ; then
      echo INFO publish was not needed, So ending the transaction
      ( cd ; cvmfs_server abort -f ; ) ;
   else
      echo INFO publish necessary
      echo INFO updating $updated_list

      # db updated_list
      date_s_now=$(echo $(/bin/date +%s) $(/bin/date -u))
      grep -q "gridpacks $(echo $f | cut -d/ -f2) $(echo $date_s_now | awk '{print $1}')" $updated_list
      if [ $? -eq 0 ] ; then
        echo Warning "gridpacks $(echo $f | cut -d/ -f2) $(echo $date_s_now | awk '{print $1}')" is already in the $updated_list
      else
        echo INFO adding "gridpacks $(echo $f | cut -d/ -f2) $(echo $date_s_now | awk '{print $1}')" to $updated_list
        echo "gridpacks $(echo $f | cut -d/ -f2) $date_s_now" >> $updated_list
      fi
      thestring="gridpacks $(echo $f | cut -d/ -f2) $(echo $date_s_now | awk '{print $1}')"

      echo INFO adding 'phys_generator/gridpacks/slc*/*/*' to /cvmfs/cms.cern.ch/.cvmfsdirtab
      # nested stuff
      grep -q /phys_generator/gridpacks/slc /cvmfs/cms.cern.ch/.cvmfsdirtab
      if [ $? -ne 0 ] ; then
         echo '/phys_generator/gridpacks/slc*/*/*' >> /cvmfs/cms.cern.ch/.cvmfsdirtab
      fi

      # fix all wrong perms if any
      echo INFO fixing all wrong perms if any
      n=0
      for f in $(find /cvmfs/cms.cern.ch/phys_generator/gridpacks/ -type f -name "*" -print) ; do
       themode=$(/usr/bin/stat -c %a $f)
       if [ $themode -lt 400 ] ; then
          n=$(expr $n + 1)
          echo chmod 644 $f
          chmod 644 $f
       fi
       if [ $(echo $themode | cut -c2-) -lt 40 ] ; then
          n=$(expr $n + 1)
          echo chmod 644 $f
          chmod 644 $f
       fi
       if [ $(echo $themode | cut -c3-) -lt 4 ] ; then
          n=$(expr $n + 1)
          echo chmod 644 $f
          chmod 644 $f
       fi
      done
      for d in $(find /cvmfs/cms.cern.ch/phys_generator/gridpacks/ -type d -name "*" -print) ; do
       themode=$(/usr/bin/stat -c %a $d)
       if [ $themode -lt 500 ] ; then
          n=$(expr $n + 1)
          echo chmod 755 $d
          chmod 755 $d
       fi
       if [ $(echo $themode | cut -c2-) -lt 50 ] ; then
          n=$(expr $n + 1)
          echo chmod 755 $d
          chmod 755 $d
       fi
       if [ $(echo $themode | cut -c3-) -lt 5 ] ; then
          n=$(expr $n + 1)
          echo chmod 755 $d
          chmod 755 $d
       fi
      done

      # end of fix all wrong perms


      echo INFO publishing $rsync_name
      currdir=$(pwd)
      cd
      time cvmfs_server publish > $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos.log 2>&1
      status=$?
      cd $currdir
      if [ $status -eq 0 ] ; then
         #printf "$(basename $0) cvmfs_server_publish OK \n$(cat $HOME/cvmfs_server+publish+rsync+generator+package+from+eos.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish for $package OK" $notifytowhom
         printf "$(basename $0) cvmfs_server_publish OK \n$(cat $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos.log | sed 's#%#%%#g')\n"
      else
         ( cd ; echo Warning deleting "$thestring" from $updated_list ; cic_del_line "$thestring" $updated_list ; ) ;
         echo ERROR failed cvmfs_server publish
         printf "$(basename $0) cvmfs_server publish failed\n$(cat $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      fi
   fi
else
   echo ERROR failed : rsync -arzuvp $rsync_source $(dirname $rsync_name)
   printf "$(basename $0) ERROR FAILED: rsync -arzuvp $rsync_source $(dirname $rsync_name)\n" | mail -s "$(basename $0) ERROR FAILED rsync" $notifytowhom
   ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
fi

next_update=$(crontab -l | grep ^[0-9] | grep cron_install_cmssw.sh | awk '{print $1}')
minutenow=$(date -u +%M)
minutediff=$(expr $next_update - $minutenow )
[ $next_update -lt $minutenow ] && minutediff=$(expr $next_update + 60 - $minutenow )

echo "At cms.cern.ch $(date -u)" > $HOME/logs/cms.cern.ch_space.txt
echo "Next update in $minutediff minutes later" >> $HOME/logs/cms.cern.ch_space.txt
df -h >> $HOME/logs/cms.cern.ch_space.txt
minutenow=$(date -u +%M)
#ngridpacklist=$(grep "tar.xz\|tar.gz\|tgz" $HOME/logs/rsync+generator+package+from+eos.log | grep "^gridpacks/" | grep -v "_noiter" | grep -v "sys.v\|sys.a" | wc -l)

# to run cms_cvmfs_check_gridpacks_diff 
grep "tar.xz\|tar.gz\|tgz" $HOME/logs/rsync+generator+package+from+eos.log | grep "^gridpacks/" | grep -v "_noiter" | grep -v "sys.v\|sys.a" > $HOME/logs/gridpacks_schedule.txt

#source $HOME/functions-cms-cvmfs-mgmt
ngridpacklist1=$(cms_cvmfs_check_gridpacks_diff | grep "^1" | wc -l)
ngridpacklist=$(cms_cvmfs_check_gridpacks_diff | grep "^2 \|^3 \|^4" | wc -l)
ngridpackfiles=$(cms_cvmfs_check_gridpacks_diff 2>/dev/null | grep "^2 \|^3 \|^4" | sed 's#%#%%#g')
alllist=$(expr $ngridpacklist1 + $ngridpacklist)
if [ $alllist -lt $NGRIDPACKS ] ; then
   sinpl="gridpacks are"
   [ $alllist -lt 2 ] && sinpl="gridpack is"
   echo "At cms.cern.ch $(date -u) : $alllist $sinpl added to /cvmfs/cms.cern.ch this time" > $HOME/logs/gridpacks_schedule.txt

   echo "Added new gridpack list starts here " >> $HOME/logs/gridpacks_schedule.txt
   printf "$ngridpackfiles\n" >> $HOME/logs/gridpacks_schedule.txt
   echo "Added new gridpack list ends here " >> $HOME/logs/gridpacks_schedule.txt
   echo "  " >> $HOME/logs/gridpacks_schedule.txt
   echo "Unfinished priority list starts here (if empty, then it is done)" >> $HOME/logs/gridpacks_schedule.txt
   for gridpack in $(higher_priority_gridpacks | sed "s#/gridpacks/# /#g" | awk '{print $NF}') ; do [ $(ls -al $rsync_source$gridpack | awk '{print $5}') -eq $(ls -al $rsync_destination$gridpack | awk '{print $5}') ] || echo $gridpack  ; done >> $HOME/logs/gridpacks_schedule.txt
   echo "Unfinished priority list ends here " >> $HOME/logs/gridpacks_schedule.txt
   echo "  " >> $HOME/logs/gridpacks_schedule.txt


   echo "Updated gridpacks (including new ones ) starts here "  >> $HOME/logs/gridpacks_schedule.txt
   for f in $UPDATED_GRIDPACKS ; do echo $f ; done   >> $HOME/logs/gridpacks_schedule.txt
   echo "Updated gridpacks starts here "  >> $HOME/logs/gridpacks_schedule.txt

   echo "" >> $HOME/logs/gridpacks_schedule.txt
   echo "" >> $HOME/logs/gridpacks_schedule.txt
   echo "" >> $HOME/logs/gridpacks_schedule.txt
else
   echo "At cms.cern.ch $(date -u) : $NGRIDPACKS of $alllist ( = $ngridpacklist1 + $ngridpacklist ) in the following list is added to /cvmfs/cms.cern.ch this time" > $HOME/logs/gridpacks_schedule.txt

   echo "Added new gridpack list starts here " >> $HOME/logs/gridpacks_schedule.txt
   printf "$ngridpackfiles\n" >> $HOME/logs/gridpacks_schedule.txt
   echo "Added new gridpack list ends here " >> $HOME/logs/gridpacks_schedule.txt
   echo "  " >> $HOME/logs/gridpacks_schedule.txt

   echo "Unfinished priority list starts here (if empty, then it is done) " >> $HOME/logs/gridpacks_schedule.txt
   for gridpack in $(higher_priority_gridpacks | sed "s#/gridpacks/# /#g" | awk '{print $NF}') ; do [ $(ls -al $rsync_source$gridpack | awk '{print $5}') -eq $(ls -al $rsync_destination$gridpack | awk '{print $5}') ] || echo $gridpack  ; done >> $HOME/logs/gridpacks_schedule.txt
   echo "Unfinished priority list ends here " >> $HOME/logs/gridpacks_schedule.txt
   echo "  " >> $HOME/logs/gridpacks_schedule.txt

   echo "Updated gridpacks (including new ones ) starts here "  >> $HOME/logs/gridpacks_schedule.txt
   for f in $UPDATED_GRIDPACKS ; do echo $f ; done   >> $HOME/logs/gridpacks_schedule.txt
   echo "Updated gridpacks starts here "  >> $HOME/logs/gridpacks_schedule.txt

   echo "" >> $HOME/logs/gridpacks_schedule.txt
   echo "" >> $HOME/logs/gridpacks_schedule.txt
   echo "" >> $HOME/logs/gridpacks_schedule.txt
fi



minutediff=$(expr $next_update - $minutenow )
[ $next_update -lt $minutenow ] && minutediff=$(expr $next_update + 60 - $minutenow )

echo "Next update in $minutediff minutes later" >> $HOME/logs/gridpacks_schedule.txt
grep "tar.xz\|tar.gz\|tgz" $HOME/logs/rsync+generator+package+from+eos.log | grep "^gridpacks/" | grep -v "_noiter" | grep -v "sys.v\|sys.a" >> $HOME/logs/gridpacks_schedule.txt
if [ -f $HOME/osg/osg-wn-client/setup.sh ] ; then
   source $HOME/osg/osg-wn-client/setup.sh
   export X509_USER_PROXY=/home/cvcms/.florida.t2.proxy
   globus-url-copy -vb file://$HOME/logs/cms.cern.ch_space.txt gsiftp://cmsio.rc.ufl.edu/cms/t2/operations/cvmfs_installations/cms.cern.ch_space.txt
   globus-url-copy -vb file://$HOME/logs/gridpacks_schedule.txt gsiftp://cmsio.rc.ufl.edu/cms/t2/operations/cvmfs_installations/gridpacks_schedule.txt
fi


echo INFO eosumount $HOME/eos2
$EOSSYS/bin/eos.select -b fuse umount $HOME/eos2
ps auxwww | grep -v grep | grep -q eosfsd
if [ $? -eq 0 ] ; then
   echo Warning eosforceumount $HOME/eos2
   eosforceumount $HOME/eos2
fi
echo INFO checking with ls $HOME/eos2
ls $HOME/eos2

echo script $0 Done
log=$HOME/logs/$(basename $0 | sed 's#\.sh#\.log#g')
eos_fuse_logs=
for f in /tmp/eos-fuse.*.log ; do
   [ -f "$f" ] && { eos_fuse_logs="$eos_fuse_logs $f" ; rm -f $f ; } ;
done
printf "$(basename $0) Done\nEOS Client Version=$EOS_CLIENT_VERSION\nRemoved $eos_fuse_logs\n$(ls -al /tmp)\n$(cat $log 2>&1 | sed 's#%#%%#g')\n"
#printf "$(basename $0) Done\nEOS Client Version=$EOS_CLIENT_VERSION\nRemoved $eos_fuse_logs\n$(ls -al /tmp)\n$(cat $log 2>&1 | sed 's#%#%%#g')\n" | mail -s "$(basename $0) Done" $notifytowhom
exit 0
