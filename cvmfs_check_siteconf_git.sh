#!/bin/sh
#
# Created by Bockjoo Kim, U of Florida
#
# CVMFS 2.1/SLC6
# version=0.7.0
cvmfs_check_siteconf_git_version=0.7.0
auth_host=oo.ihepa.ufl.edu
cvmfs_server_name=$(grep cvmfs_server_name= $HOME/cron_install_cmssw.config | grep -v \# | cut -d= -f2)
cvmfs_server_name=$(eval echo $cvmfs_server_name)
#cvmfs_siteconf_dir=siteconf
cvmfs_top=/cvmfs/cms.cern.ch                                        # CERN
cvmfs_siteconf_dir=SITECONF
cvmfs_siteconf_others="T2_CH_CERN/Tier0/override_catalog.xml"
cvmfs_siteconf_glideinconfigs="*/GlideinConfig/local-users.txt
*/GlideinConfig/local-groups.txt
*/GlideinConfig/config.ini
*/GlideinConfig/setup.sh"
#cvmfs_sites_removed="T1_DE_FZK T1_TW_ASGC T2_Belgium T2_CH_CAF T2_Desy T2_LIP-Coimbra T2_LIP-Lisbon T2_PT_LIP_Coimbra T2_PT_LIP_Lisbon T2_TW_Taiwan T3_US_Vanderbilt T2_UK_SouthGrid_RALPPD T3_DE_Karlsruhe T3_GR_IASA_GR T3_GR_IASA_HG T3_IT_Padova T3_UK_ScotGrid_DUR"

#topsiteconf=/scratch/shared/SITECONF
# CVMFS 2.0/SLC5 topsiteconf=/scratch/shared/cms/local_SITECONF                      # CERN
# CVMFS 2.1/SLC6
topsiteconf=$HOME/cms/local_SITECONF                      # CERN
if [ $(/bin/hostname -f) == $auth_host ] ; then
   topsiteconf=/state/partition1/coldhead/services/cms/local_SITECONF  # Florida
fi
#cvmfs_top=/state/partition1/coldhead/services/cms/local_SITECONF    # Florida

cvmfs_siteconf=$cvmfs_top/SITECONF
notifytowhom=$(grep notifytowhom= $HOME/cron_install_cmssw.config | grep -v \# | cut -d= -f2)

export CVSROOT=":pserver:anonymous@cmssw.cvs.cern.ch:/local/reps/CMSSW"
export CMSSW_GIT_REFERENCE=/afs/cern.ch/cms/git-cmssw-mirror/cmssw.git

updated_list=/cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates
[ -d $topsiteconf ] || mkdir -p $topsiteconf


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


lock=$(/usr/bin/dirname $topsiteconf)/cvmfs_server+publish.lock

# proxy
#export X509_CERT_DIR=/etc/grid-security/certificates
#export X509_USER_PROXY=$HOME/.cmssoft/cmsuser.proxy
#export X509_USER_PROXY=$HOME/t2/operations/hostproxy.pem

the_command_out=$HOME/$(basename $0 | sed "s#\.sh##g")+the_command_out.log

if [ -f $lock ] ; then
   echo INFO $lock exists
   printf "$(basename $0) Warning lock exists\n" | mail -s "$(basename $0) Warning lock exists" $notifytowhom
   exit 0
fi

now_date_h=$(/bin/date +%Y%m%d%H)
downtime_start=2013032601
downtime_end=2013032700
git_switch_start=2013062523
git_switch_day1=2013062623
#if [ $now_date_h -gt $git_switch_start ] ; then
#   cvmfs_siteconf_dir=SITECONF
#   [ $now_date_h -lt 2013062602 ] && printf "$(basename $0) git switch started $(date) \n" | mail -s "$(basename $0) git/cvs" $notifytowhom
#else
#   printf "$(basename $0) git/cvs $(date) \n" | mail -s "$(basename $0) git/cvs" $notifytowhom
#fi

if [ $(/bin/hostname -f) == $cvmfs_server_name ] ; then
   if [ ! -d $cvmfs_top/$cvmfs_siteconf_dir ] ; then
      printf "$(basename $0) for creating siteconf dir\n" | mail -s "cvmfs_server transaction started" $notifytowhom
      echo INFO creating $cvmfs_top/$cvmfs_siteconf_dir
      cvmfs_server transaction
      status=$?
      what="$(basename $0) cvmfs_top/cvmfs_siteconf_dir"
      cvmfs_server_transaction_check $status $what
      if [ $? -eq 0 ] ; then
         echo INFO transaction OK for $what
      else
         printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
         rm -f $lock
         exit 1
      fi
      mkdir -p $cvmfs_top/$cvmfs_siteconf_dir
      cd $HOME
      time cvmfs_server publish > $HOME/cvmfs_server+publish+siteconf.log 2>&1
      status=$?
      cd $currdir
      if [ $status -eq 0 ] ; then
         echo INFO cvmfs publication successful   # ( cd ; cvmfs_server abort -f ; ) ; #cvmfs_server abort -f
      else
         echo INFO cvmfs publication failed
         printf "$(basename $0) ERROR CVMFS published failed after mkdir -p $cvmfs_top/$cvmfs_siteconf_dir\n" | mail -s "$(basename $0) ERROR CVMFS published failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
         exit 1
      fi
   fi
fi

if [ $now_date_h -gt $downtime_start ] ;  then
   if [ $now_date_h -lt $downtime_end ] ; then
      printf "$(basename $0) Stratum0 maintenance $(date) \n" | mail -s "$(basename $0) Stratum 0 maintenance " $notifytowhom
      rm -f $lock
      exit 0
   fi
fi

echo INFO topsiteconf=$topsiteconf on $(/bin/hostname -f) 
if [ $(/bin/hostname -f) == $auth_host ] ; then
   export X509_CERT_DIR=/etc/grid-security/certificates
   export X509_USER_PROXY=$HOME/.cmssoft/cmsuser.proxy
   #/usr/bin/curl -ks --cert $X509_USER_PROXY --key $X509_USER_PROXY -X GET "https://cmsweb.cern.ch/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD" -o $topsiteconf/HEAD.tgz
   #voms-proxy-info -all
   #echo DEBUG using $X509_USER_PROXY
   #echo /usr/bin/curl -ks --cert $X509_USER_PROXY --key $X509_USER_PROXY -X GET "https://cmsweb.cern.ch/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD" -o $HOME/services/external/apache2/htdocs/t2/operations/siteconf_HEAD.tgz
   /usr/bin/curl -ks --cert $X509_USER_PROXY --key $X509_USER_PROXY -X GET "https://cmsweb.cern.ch/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD" -o $HOME/services/external/apache2/htdocs/t2/operations/siteconf_HEAD.tgz
   if [ $? -ne 0 ] ; then
      echo ERROR downloading siteconf HEAD.tgz failed
      printf "$(basename $0) ERROR downloading siteconf HEAD.tgz failed\n" | mail -s "$(basename $0) ERROR downloading siteconf HEAD.tgz failed" $notifytowhom
      rm -f $lock
      exit 1
   fi
   cp $HOME/services/external/apache2/htdocs/t2/operations/siteconf_HEAD.tgz $topsiteconf/HEAD.tgz
   file $HOME/services/external/apache2/htdocs/t2/operations/siteconf_HEAD.tgz 
   # COMMENT out the following three lines to test locally
   echo INFO $topsiteconf/HEAD.tgz downloaded
   
   rm -f $lock
   exit 0

else
   if [ 1 ] ; then
      echo INFO executing $HOME/create_host_proxy_download_siteconf.sh
      $HOME/create_host_proxy_download_siteconf.sh $topsiteconf 2>&1 | tee $HOME/create_host_proxy_download_siteconf.log
      if [ $? -ne 0 ] ; then
        printf "$(basename $0) ERROR failed: $HOME/create_host_proxy_download_siteconf.sh $topsiteconf\n$(cat $HOME/create_host_proxy_download_siteconf.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) ERROR $HOME/create_host_proxy_download_siteconf.sh failed" $notifytowhom
        rm -f $lock
        exit 1
      fi
   else
      /usr/bin/curl -X GET http://${auth_host}:8080/t2/operations/siteconf_HEAD.tgz -o $topsiteconf/HEAD.tgz
      if [ $? -ne 0 ] ; then
         echo ERROR downloading siteconf HEAD.tgz failed
         printf "$(basename $0) ERROR downloading siteconf HEAD.tgz failed\n" | mail -s "$(basename $0) ERROR downloading siteconf HEAD.tgz failed" $notifytowhom
         rm -f $lock
         exit 1
      fi
   fi
fi
(cd $topsiteconf ; tar xzf HEAD.tgz ; exit $?)
if [ $? -ne 0 ] ; then
   echo ERROR extracting HEAD.tgz failed
   printf "$(basename $0) ERROR extracting HEAD.tgz failed \nChecking HEAD.tgz uner $topsiteconf \n$(ls -al $topsiteconf)\n" | mail -s "$(basename $0) ERROR extracting HEAD.tgz failed" $notifytowhom
   rm -f $lock
   exit 1
fi

extra_siteconf_files=
for f in $cvmfs_siteconf_others ; do
    thefile="$(echo $topsiteconf/siteconf*/$f)"
    echo DEBUG thefile=$thefile
    if [ -f "$thefile" ] ; then
       echo DEBUG adding $f to the extra_site_conf_files list
       extra_siteconf_files="$extra_siteconf_files $thefile"
    fi
done
for f in $cvmfs_siteconf_glideinconfigs ; do
    thefiles="$(echo $topsiteconf/siteconf*/$f)"
    for thefile in $thefiles ; do
      echo DEBUG thefile=$thefile
      if [ -f "$thefile" ] ; then
       echo DEBUG adding $f to the extra_site_conf_files list
       extra_siteconf_files="$extra_siteconf_files $thefile"
      fi
    done
done

cvmfs_sites_that_will_be_removed= # NEW 28JAN2016 to get rid of some sites from the SITECONF

slc_xml=
for f in $topsiteconf/siteconf*/*/*/site-local-config* $extra_siteconf_files ; do
if [ ] ; then
   # NEW 28JAN2016 to get rid of some sites from the SITECONF
   ignore=no
   for site in $cvmfs_sites_removed ; do
       echo $f | grep -q /${site}/
       if [ $? -eq 0 ] ; then
          ignore=yes
          # if it still exists take it out
          thedir=${cvmfs_top}/${cvmfs_siteconf_dir}/${site}
          echo "$cvmfs_sites_that_will_be_removed" | grep -q $thedir
          if [ $? -ne 0 ] ; then
             cvmfs_sites_that_will_be_removed="$cvmfs_sites_that_will_be_removed $thedir"
          fi
          break
       fi
   done

   [ "x$ignore" == "xyes" ] && continue
   # NEW 28JAN2016 to get rid of some sites from the SITECONF
fi # if [ ] ; then
   thefile=$(echo $f | sed "s#/# #g" | awk '{print $(NF-2)"/"$(NF-1)"/"$NF}')
   if [ ! -f $f ] ; then
      if [ ! -f $cvmfs_top/${cvmfs_siteconf_dir}/$thefile ] ; then
         echo INFO Nothing in the git and nothing in the CVMFS. No file to be updated
         continue
      fi
   fi
   echo DEBUG doing checksum on $f
   cksum $f
   [ $? -eq 0 ] || { echo DEBUG checksum on $f failed ; continue ; } ;
   cksum_git=$(cksum $f | awk '{print $1"+"$2}')
   echo DEBUG doing checsum on $cvmfs_top/${cvmfs_siteconf_dir}/$thefile 
   cksum $cvmfs_top/${cvmfs_siteconf_dir}/$thefile
   cksum_cvmfs=$(cksum $cvmfs_top/${cvmfs_siteconf_dir}/$thefile | awk '{print $1"+"$2}')
   echo DEBUG $thefile $cksum_git vs $cksum_cvmfs
   [ "x$cksum_git" == "x$cksum_cvmfs" ] && continue
   slc_xml="$thefile $slc_xml"
done

storage_xml=
for f in $topsiteconf/siteconf*/*/*/storage* ; do
if [ ] ; then
   # NEW 28JAN2016 to get rid of some sites from the SITECONF
   ignore=no
   for site in $cvmfs_sites_removed ; do
       echo $f | grep -q /${site}/
       if [ $? -eq 0 ] ; then
          ignore=yes
          # if it still exists take it out
          thedir=${cvmfs_top}/${cvmfs_siteconf_dir}/${site}
          echo "$cvmfs_sites_that_will_be_removed" | grep -q $thedir
          if [ $? -ne 0 ] ; then
             cvmfs_sites_that_will_be_removed="$cvmfs_sites_that_will_be_removed $thedir"
          fi
          break
       fi
   done

   [ "x$ignore" == "xyes" ] && continue
   # NEW 28JAN2016 to get rid of some sites from the SITECONF
fi # if [ ] ; then
   thefile=$(echo $f | sed "s#/# #g" | awk '{print $(NF-2)"/"$(NF-1)"/"$NF}')
   if [ ! -f $f ] ; then
      if [ ! -f $cvmfs_top/${cvmfs_siteconf_dir}/$thefile ] ; then
         echo INFO Nothing in the git and nothing in the CVMFS. No file to be updated
         continue
      fi
   fi
   echo DEBUG doing checksum on $f
   cksum $f
   [ $? -eq 0 ] || { echo DEBUG checksum on $f failed ; continue ; } ;
   cksum_git=$(cksum $f | awk '{print $1"+"$2}')
   echo DEBUG doing checsum on $cvmfs_top/${cvmfs_siteconf_dir}/$thefile 
   cksum $cvmfs_top/${cvmfs_siteconf_dir}/$thefile
   cksum_cvmfs=$(cksum $cvmfs_top/${cvmfs_siteconf_dir}/$thefile | awk '{print $1"+"$2}')
   echo DEBUG $thefile $cksum_git vs $cksum_cvmfs
   #cksum_git=$(cksum $f | awk '{print $1"+"$2}')
   #cksum_cvmfs=$(cksum $cvmfs_top/${cvmfs_siteconf_dir}/$thefile | awk '{print $1"+"$2}')
   #echo DEBUG $thefile $cksum_git vs $cksum_cvmfs
   [ "x$cksum_git" == "x$cksum_cvmfs" ] && continue
   storage_xml="$thefile $storage_xml"
done

cmsset_sh=
for f in $topsiteconf/siteconf*/*/*/cmsset* ; do
if [ ] ; then
   # NEW 28JAN2016 to get rid of some sites from the SITECONF
   ignore=no
   for site in $cvmfs_sites_removed ; do
       echo $f | grep -q /${site}/
       if [ $? -eq 0 ] ; then
          ignore=yes
          # if it still exists take it out
          thedir=${cvmfs_top}/${cvmfs_siteconf_dir}/${site}
          echo "$cvmfs_sites_that_will_be_removed" | grep -q $thedir
          if [ $? -ne 0 ] ; then
             cvmfs_sites_that_will_be_removed="$cvmfs_sites_that_will_be_removed $thedir"
          fi
          break
       fi
   done

   [ "x$ignore" == "xyes" ] && continue
   # NEW 28JAN2016 to get rid of some sites from the SITECONF
fi
   thefile=$(echo $f | sed "s#/# #g" | awk '{print $(NF-2)"/"$(NF-1)"/"$NF}')
   if [ ! -f $f ] ; then
      if [ ! -f $cvmfs_top/${cvmfs_siteconf_dir}/$thefile ] ; then
         echo INFO Nothing in the git and nothing in the CVMFS. No file to be updated
         continue
      fi
   fi
   echo DEBUG doing checksum on $f
   cksum $f
   [ $? -eq 0 ] || { echo DEBUG checksum on $f failed ; continue ; } ;
   cksum_git=$(cksum $f | awk '{print $1"+"$2}')
   echo DEBUG doing checsum on $cvmfs_top/${cvmfs_siteconf_dir}/$thefile 
   cksum $cvmfs_top/${cvmfs_siteconf_dir}/$thefile
   cksum_cvmfs=$(cksum $cvmfs_top/${cvmfs_siteconf_dir}/$thefile | awk '{print $1"+"$2}')
   echo DEBUG $thefile $cksum_git vs $cksum_cvmfs
   #cksum_git=$(cksum $f | awk '{print $1"+"$2}')
   #cksum_cvmfs=$(cksum $cvmfs_top/${cvmfs_siteconf_dir}/$thefile | awk '{print $1"+"$2}')
   #echo DEBUG $thefile $cksum_git vs $cksum_cvmfs
   [ "x$cksum_git" == "x$cksum_cvmfs" ] && continue
   cmsset_sh="$thefile $cmsset_sh"
done

files_to_be_updated="$(echo $(echo $slc_xml $storage_xml $cmsset_sh))"
full_path_prefix=$(echo $topsiteconf/siteconf-*)

for siteconf_site in $cvmfs_sites_removed ; do
    thedir=${cvmfs_top}/${cvmfs_siteconf_dir}/${siteconf_site}
    [ -d $thedir ] || continue
    echo "$cvmfs_sites_that_will_be_removed" | grep -q $thedir
    if [ $? -ne 0 ] ; then
             cvmfs_sites_that_will_be_removed="$cvmfs_sites_that_will_be_removed $thedir"
    fi
done


# check against the sitedb
export X509_USER_PROXY=$HOME/.florida.t2.proxy
sitedbsites=$(/usr/bin/curl --capath /etc/grid-security/certificates --cacert $X509_USER_PROXY --cert $X509_USER_PROXY --key $X509_USER_PROXY -X GET https://cmsweb.cern.ch/sitedb/data/prod/site-names 2>/dev/null)
status=$?
sites_to_keep_git=$(for f in $topsiteconf/siteconf*/* ; do basename $f ; done)
echo DEBUG sites_to_keep_git
for f in $topsiteconf/siteconf*/* ; do echo DEBUG $(basename $f) ; done

sites_to_keep_sitedb=$(for s in $sitedbsites ; do echo $s ; done | grep \"T[0-9] | cut -d\" -f2 | sort -n | sort -u)
cvmfs_sites_that_will_be_removed=
echo DEBUG $cvmfs_top/$cvmfs_siteconf_dir
for s in $(ls -d $cvmfs_top/$cvmfs_siteconf_dir/T*) ; do
    echo DEBUG $(basename $s) using ls -d
    for s_keep in $sites_to_keep_git $sites_to_keep_sitedb ; do echo $s_keep ; done | sort -u | grep -q $(basename $s)$
    if [ $? -eq 0 ] ; then
      echo DEBUG Looking for $s from $sites_to_keep_git $sites_to_keep_sitedb
      #for s_keep in $sites_to_keep_git $sites_to_keep_sitedb ; do echo $s_keep ; done | sort -u | grep $(basename $s)$
    else
      cvmfs_sites_that_will_be_removed="$cvmfs_sites_that_will_be_removed $s"
    fi
done
#cvmfs_sites_that_will_be_removed_unique=$(for site_to_be_removed in $cvmfs_sites_that_will_be_removed ; do echo $site_to_be_removed ; done | sort -u)
echo DEBUG cvmfs_sites_that_will_be_removed was
echo "$cvmfs_sites_that_will_be_removed"

if [ $status -eq 0 ] ; then
   if [ "x$sitedbsites" == "x" ] ; then # Something wrong with something (proxy or sitesitedb )
      cvmfs_sites_that_will_be_removed= # $cvmfs_sites_that_will_be_removed_unique
   else
      cvmfs_sites_that_will_be_removed=$(for site_to_be_removed in $cvmfs_sites_that_will_be_removed ; do echo $site_to_be_removed ; done | sort -u)
if [ ] ; then
      cvmfs_sites_that_will_be_removed_unique=$(for site_to_be_removed in $cvmfs_sites_that_will_be_removed ; do echo $site_to_be_removed ; done | sort -u)
      cvmfs_sites_that_will_be_removed=
      for site_to_be_removed in $cvmfs_sites_that_will_be_removed_unique ; do
         echo DEBUG doing site_to_be_removed $site_to_be_removed
         [ "x$sitedbsites" == "x" ] && break
         [ -d $site_to_be_removed ] || continue # no reason to remove nothing
         echo "$sitedbsites" | grep -q \"$(basename $site_to_be_removed)\"
         if [ $? -eq 0 ] ; then
            cvmfs_sites_that_will_be_removed="$cvmfs_sites_that_will_be_removed ${site_to_be_removed}_exists_in_siteDB"
         else
            cvmfs_sites_that_will_be_removed="$cvmfs_sites_that_will_be_removed $site_to_be_removed"
         fi
      done
fi # if [ ] ; then
   fi
else # we can not determine reliably $cvmfs_sites_that_will_be_removed
   cvmfs_sites_that_will_be_removed=
fi
echo DEBUG cvmfs_sites_that_will_be_removed is
echo "$cvmfs_sites_that_will_be_removed"

if [ "x$cvmfs_sites_that_will_be_removed" != "x" ] ; then
   printf "$(basename $0) there are cvmfs_sites_that_will_be_removed\n$cvmfs_sites_that_will_be_removed\n" | mail -s "cvmfs_server transaction started" $notifytowhom
   cvmfs_server transaction
   status1=$?
   what="$(basename $0)+cvmfs_sites_that_will_be_removed_exists"
   cvmfs_server_transaction_check $status1 $what
   if [ $? -eq 0 ] ; then
      echo INFO transaction OK for $what
      for thedir in $cvmfs_sites_that_will_be_removed ; do
          cvmfs_root_dir=$(dirname $thedir)
          cd $cvmfs_root_dir
          thesite=$(basename $thedir)
          # just to ensure it is a site name that starts with T[0-9]_
          echo $thesite | grep -q $thesite
          [ $? -eq 0 ] && { echo rm -rf $thesite from $(pwd) at $(date) ; rm -rf $thesite ; } ;
          cd -
      done > $HOME/cvmfs_server+publish+siteconf.log 2>&1
      cat $HOME/cvmfs_server+publish+siteconf.log
      printf "CVMFS SITECONF sites that will be removed: $(echo $cvmfs_sites_that_will_be_removed | wc -w) sites\n$cvmfs_sites_that_will_be_removed\n\n$(cat $HOME/cvmfs_server+publish+siteconf.log)\n" | sed 's#%#%%#g' | mail -s "Removing sites from the SITECONF" $notifytowhom
      cd
      time cvmfs_server publish > $HOME/cvmfs_server+publish+siteconf.log 2>&1
      status=$?
      cd -      
      if [ $status -eq 0 ] ; then
         echo INFO cvmfs publication successful
         printf "$(basename $0) CVMFS cvmfs publication successful after removing SITECONF inactive sites\n" | mail -s "$(basename $0) CVMFS published" $notifytowhom
      else
         echo INFO cvmfs publication failed
         printf "$(basename $0) ERROR CVMFS published failed\n for \n$cvmfs_sites_that_will_be_removed\n$HOME/cvmfs_server+publish+siteconf.log Content follows\n$(cat $HOME/cvmfs_server+publish+siteconf.log)\n" | mail -s "$(basename $0) ERROR CVMFS published failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      fi
   else
      printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
      #rm -f $lock
      #exit 1
   fi
fi

if [ "x$files_to_be_updated" != "x" ] ; then
   printf "$(basename $0) there are files to be updated\n" | mail -s "cvmfs_server transaction started" $notifytowhom
   cvmfs_server transaction
   status1=$?
   what="$(basename $0) files_to_be_updated exist"
   cvmfs_server_transaction_check $status1 $what
   if [ $? -eq 0 ] ; then
      echo INFO transaction OK for $what
   else
      printf "cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
      rm -f $lock
      exit 1
   fi
fi

status=0
for f in $files_to_be_updated ; do
   
   if [ $(/bin/hostname -f) == $cvmfs_server_name ] ; then
      echo INFO updating $f on the cvmfs
      if [ ! -d $cvmfs_top/${cvmfs_siteconf_dir}/$(dirname $f) ] ; then
         mkdir -p $cvmfs_top/${cvmfs_siteconf_dir}/$(dirname $f)
      fi
      /bin/cp $full_path_prefix/$f $cvmfs_top/${cvmfs_siteconf_dir}/$(dirname $f)/
      status=$(expr $status + $?)
   else
      echo INFO $f will need to be updated on $cvmfs_server_name
      echo       /bin/cp $full_path_prefix/$f $cvmfs_top/${cvmfs_siteconf_dir}/$f
   fi
done






if [ "x$files_to_be_updated" == "x" ] ; then
   echo INFO no files to be updated
else
   sites_updated=$(echo $(for cf in $files_to_be_updated ; do echo $cf ; done | sed "s#/# #g" | awk '{print $1}' | grep T[0-9]_ | sort -u))
   echo INFO sites to be updated: $sites_updated
   #printf "$(basename $0): INFO \nFiles Updated in git \n$(for f in $files_to_be_updated ; do echo $f ; done)\nSites: $(for s in $sites_updated ; do echo $s ; done)\n" | mail -s "$(basename $0): INFO Files Updated in git " $notifytowhom
   if [ "x$sites_updated" == "x" ] ; then
      printf "$(basename $0): Warning strange sites_updated is empty\nfiles_updated is $files_updated\n" | mail -s "$(basename $0): Warning strange sites_updated is empty" $notifytowhom
   else
      YMDM=$(date -u +%Y%m%d%H)
      grep "$YMDM " $updated_list | grep -q "$sites_updated"
      if [ $? -ne 0 ] ; then
         echo $YMDM $(/bin/date +%s) $(/bin/date -u) "$sites_updated" to $updated_list
         [ $(/bin/hostname -f) == $cvmfs_server_name ] && echo $YMDM $(/bin/date +%s) $(/bin/date -u) "$sites_updated" >> $updated_list
      fi
   fi
   if [ $(/bin/hostname -f) == $cvmfs_server_name ] ; then
      echo INFO executing time cvmfs_server publish
      currdir=$(pwd)
      cd $HOME
      time cvmfs_server publish > $HOME/cvmfs_server+publish+siteconf.log 2>&1
      status=$?
      cd $currdir
      if [ $status -eq 0 ] ; then
         echo INFO cvmfs publication successful
      else
         echo INFO cvmfs publication failed
         printf "$(basename $0) ERROR CVMFS published failed\nFiles Updated\n$(for f in $files_to_be_updated ; do echo $f ; done)\n$HOME/cvmfs_server+publish+siteconf.log Content follows\n$(cat $HOME/cvmfs_server+publish+siteconf.log)\n" | mail -s "$(basename $0) ERROR CVMFS published failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      fi
   else
      echo INFO time cvmfs_server publish needs to be executed on $cvmfs_server_name
   fi
fi
rm -rf $topsiteconf/siteconf-*
#rm -rf $topsiteconf/HEAD.tgz
rm -f $lock
exit 0
