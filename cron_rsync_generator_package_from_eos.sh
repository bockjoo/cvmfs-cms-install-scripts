#!/bin/bash
# versiono 0.1.5
version=0.1.5
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

eos () {
  /afs/cern.ch/project/eos/installation/${EOS_CLIENT_VERSION}/bin/eos.select
  return $?
}

eoscms () {
  /afs/cern.ch/project/eos/installation/${EOS_CLIENT_VERSION}/bin/eos.select
  return $?
}

eosforceumount () {
  killall eosfsd 2>/dev/null
  killall -9 eosfsd 2>/dev/null
  fusermount -u $1
  return $?
}

eosmount () {
  /afs/cern.ch/project/eos/installation/${EOS_CLIENT_VERSION}/bin/eos.select -b fuse mount $1
  return $?  
}

eosumount () {
  /afs/cern.ch/project/eos/installation/${EOS_CLIENT_VERSION}/bin/eos.select -b fuse umount $1
  return $?
}



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
   /usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v srm://srm.ihepa.ufl.edu:8443/srm/v2/server?SFN=/cms/t2/operations/.cmsphedex.proxy  file://$X509_USER_PROXY.copy
if [ $? -eq 0 ] ; then
   cp $X509_USER_PROXY.copy $X509_USER_PROXY
      voms-proxy-info -all
else
      printf "$(basename $0) ERROR failed to download $X509_USER_PROXY\n$(/usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v srm://srm.ihepa.ufl.edu:8443/srm/v2/server?SFN=/cms/t2/operations/.cmsphedex.proxy  file://${X509_USER_PROXY}.copy 2>&1 | sed 's#%#%%#g')n" | mail -s "$(basename $0) ERROR proxy download failed" $notifytowhom
fi

timeleft=$(voms-proxy-info -timeleft 2>/dev/null)
if [ $timeleft -lt 1900 ] ; then # 1800 + 100
   #/usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v srm://srm.ihepa.ufl.edu:8443/srm/v2/server?SFN=/cms/t2/operations/.cmsphedex.proxy  file://$X509_USER_PROXY
   /usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v srm://srm.ihepa.ufl.edu:8443/srm/v2/server?SFN=/cms/t2/operations/.cmsphedex.proxy  file://$X509_USER_PROXY.copy
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
   eosmount $HOME/eos2
fi

if [ ! -d $rsync_source ] ; then
   echo ERROR rsync_source not found eosmount error
   printf "$(basename $0) $rsync_source not found \n Issue with: eosmount $HOME/eos2 did not work\nls $HOME/eos2/cms follows\n$(ls $HOME/eos2/cms)\ntail -10 eos log\n$(tail -10 /tmp/eos*)" | mail -s "$(basename $0) ERROR eosmount $HOME/eos2 failed " $notifytowhom
   eosumount $HOME/eos2
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
   if [ ] ; then
      eosumount $HOME/eos2
      ps auxwww | grep -v grep | grep -q eosfsd
      if [ $? -eq 0 ] ; then
         echo Warning eosforceumount $HOME/eos2
         eosforceumount $HOME/eos2
      fi
      ls $HOME/eos2
      exit 1
   fi
fi

echo INFO looks good TOTAL_RSYNC_SIZE "<" TOTAL_RSYNC_SIZE_LIMIT

# Check Point 1
#echo rsync -arzuvp --delete $rsync_source $(dirname $rsync_name)
#exit 0

echo INFO Doing cvmfs_server transaction
cvmfs_server transaction
status=$?
what="$(basename $0)"
cvmfs_server_transaction_check $status $what
if [ $? -eq 0 ] ; then
   echo INFO transaction OK for $what
else
   echo ERROR transaction check FAILED
   printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
   eosumount $HOME/eos2
   ps auxwww | grep -v grep | grep -q eosfsd
   if [ $? -eq 0 ] ; then
      echo Warning eosforceumount $HOME/eos2
      eosforceumount $HOME/eos2
   fi
   ls $HOME/eos2
   exit 1
fi

echo DEBUG check point will execute 
#echo rsync -arzuvp $rsync_source $(dirname $rsync_name)
#rm -f $HOME/rsync+generator+package+from+eos.log
#rsync -arzuvp $rsync_source $(dirname $rsync_name) 2>&1 | tee $HOME/rsync+generator+package+from+eos.log
echo rsync -arzuvp --delete $rsync_source $(dirname $rsync_name)
thelog=$HOME/logs/rsync+generator+package+from+eos.log
rm -f $thelog
rsync -arzuvp --delete $rsync_source $(dirname $rsync_name) > $thelog 2>&1
status=$?
cat $thelog
if [ $status -eq 0 ] ; then
   publish_needed=0
   i=0
   for f in $(grep ^$(basename $rsync_source) $thelog 2>/dev/null) ; do
      i=$(expr $i + 1)
      [ -f "$(dirname $rsync_name)/$f" ] || { echo "[ $i ] " $(dirname $rsync_name)/$f is not a file $publish_needed ; continue ; } ;
      publish_needed=1
      echo "[ $i ] " $(dirname $rsync_name)/$f is a file $publish_needed
      INDIVIDUAL_RSYNC_SIZE=$(/usr/bin/du -s $(dirname $rsync_name)/$f | awk '{print $1}')
      INDIVIDUAL_RSYNC_SIZE=$(echo "scale=2 ; $INDIVIDUAL_RSYNC_SIZE / 1024 / 1024" | bc | cut -d. -f1)
      [ "x$INDIVIDUAL_RSYNC_SIZE" == "x" ] && INDIVIDUAL_RSYNC_SIZE=0
      if [ $INDIVIDUAL_RSYNC_SIZE -gt $INDIVIDUAL_RSYNC_SIZE_LIMIT ] ; then
         echo ERROR INDIVIDUAL_RSYNC_SIZE -gt INDIVIDUAL_RSYNC_SIZE_LIMIT $INDIVIDUAL_RSYNC_SIZE -gt $INDIVIDUAL_RSYNC_SIZE_LIMIT
         printf "$(basename $0) ERROR INDIVIDUAL_RSYNC_SIZE > INDIVIDUAL_RSYNC_SIZE_LIMIT : $INDIVIDUAL_RSYNC_SIZE > $INDIVIDUAL_RSYNC_SIZE_LIMIT $(dirname $rsync_name)/$f \n Will not publish the rsync result" | mail -s "$(basename $0) ERROR ERROR INDIVIDUAL_RSYNC_SIZE > INDIVIDUAL_RSYNC_SIZE_LIMIT" $notifytowhom
         publish_needed=0
         break
      fi
   done

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

      echo INFO publishing $rsync_name
      currdir=$(pwd)
      cd
      time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos.log
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

echo INFO eosumount $HOME/eos2
eosumount $HOME/eos2
ps auxwww | grep -v grep | grep -q eosfsd
if [ $? -eq 0 ] ; then
   echo Warning eosforceumount $HOME/eos2
   eosforceumount $HOME/eos2
fi
echo INFO checking with ls $HOME/eos2
ls $HOME/eos2

echo script $0 Done
log=$(basename $0 | sed 's#\.sh#\.log#g')
#printf "$(basename $0) Done\nEOS Client Version=$EOS_CLIENT_VERSION\n$(cat $log 2>&1 | sed 's#%#%%#g')\n" | mail -s "$(basename $0) Done" $notifytowhom
exit 0
