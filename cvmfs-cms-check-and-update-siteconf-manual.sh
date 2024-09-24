#!/bin/bash
# Manual update
if [ $# -lt 1 ] ; then
    echo ERROR $0 sitename
    exit 1
fi
TMP_AREA=$(pwd)/tmp
SYNC_DIR=$TMP_AREA #"$HOME/SITECONF"
[ -d $SYNC_DIR/SITECONF ] || mkdir $SYNC_DIR/SITECONF
RSYNC_SITES="/cvmfs/cms.cern.ch/SITECONF"
SITE=$1 #T1_DE_KIT
siteid_list=$HOME/siteid_list.txt
thesiteid=$(grep $SITE $siteid_list | awk '{print $NF}' | sort -u)
[ -f $TMP_AREA/.timestamp ] || cp /cvmfs/cms.cern.ch/SITECONF/.timestamp $TMP_AREA/
echo https://gitlab.cern.ch/api/v4/projects/$(echo ${thesiteid})/repository/archive.tar.gz?ref=master # browse it and download it as $HOME/tmp/archive_${SITE}.tgz 
export X509_USER_PROXY=$(pwd)/proxy
gfal-copy davs://cmsio2.rc.ufl.edu:1094/store/user/bockjoo/archive_${SITE}.tgz ${TMP_AREA}/
if [ $? -ne 0 ] ; then
    echo ERROR failed gfal-copy davs://cmsio2.rc.ufl.edu:1094/store/user/bockjoo/archive_${SITE}.tgz ${TMP_AREA}/
    echo INFO check $X509_USER_PROXY via voms-proxy-info -all $X509_USER_PROXY
    echo INFO browse https://gitlab.cern.ch/api/v4/projects/$(echo ${thesiteid})/repository/archive.tar.gz?ref=master to download it as archive_${SITE}.tgz and scp archive_${SITE}.tgz hpg:/cmsuf/data/store/user/bockjoo/
    exit 1
fi
rm -rf ${SYNC_DIR}/SITECONF/${SITE}

TAR_DIR=$((/bin/tar -tzf ${TMP_AREA}/archive_${SITE}.tgz | /usr/bin/awk -F/ '{print $1;exit}') 2>/dev/null)
TAR_LST=$((/bin/tar -tzf ${TMP_AREA}/archive_${SITE}.tgz | /usr/bin/awk -F/ '{if((($2=="JobConfig")&&(match($3,".*site-local-config.*\\.xml$")!=0))||(($2=="JobConfig")&&(match($3,"^cmsset_.*\\.c?sh$")!=0))||(($2=="PhEDEx")&&(match($3,".*storage.*\\.xml$")!=0))||(($2=="Tier0")&&($3=="override_catalog.xml"))||(($2=="GlideinConfig")&&($3==""))||(match($2,".*storage.*\\.json$")!=0)||(match($3,".*storage.*\\.json$")!=0)||(($2=="testing")&&($3==""))||(($2!="testing")&&($3=="JobConfig")&&(match($4,".*\\.xml$")!=0))||(($2!="testing")&&($3=="JobConfig")&&(match($4,"^cmsset_.*\\.c?sh$")!=0))||(($2!="testing")&&($3=="GlideinConfig")&&($4==""))||(($2=="ClassAd")&&(match($3,"^CMSSF_.*\\.c?sh$")!=0))||(($2!="testing")&&($3=="ClassAd")&&(match($4,"^CMSSF_.*\\.c?sh$")!=0)))print $0}') 2>/dev/null)
# Sites that do not have xml files in the gitlab
[ -s ${TMP_AREA}/archive_${SITE}.tgz ] && { [ $(tar tzvf ${TMP_AREA}/archive_${SITE}.tgz 2>&1 | grep -q xml ; echo $?) -eq 0 ] || { echo ERROR $SITE does not have any xml file ; exit 1 ; } ; } ;

if [ -n "${TAR_LST}" ]; then
      status=$( cd ${SYNC_DIR}/SITECONF > /dev/null 2>&1 ; /bin/tar -xzf ${TMP_AREA}/archive_${SITE}.tgz ${TAR_LST} > /dev/null 2>&1 ; echo $? )
else
      if [ "x$(echo ${TAR_DIR})" != "x" ] ; then
         status=$(/bin/mkdir -p ${SYNC_DIR}/SITECONF/${TAR_DIR} > /dev/null 2>&1 ; echo $?) ;
         status=$(/bin/mkdir -p ${SYNC_DIR}/SITECONF/${TAR_DIR}/JobConfig > /dev/null 2>&1 ; echo $(expr $status + $?))
      fi
fi
[ $status -eq 0 ] || { echo ERROR failed to extract tar archive of ${SITE} ; exit 1 ; } ;
/bin/rm ${TMP_AREA}/archive_${SITE}.tgz
( export X509_USER_PROXY=$(pwd)/proxy ; gfal-rm davs://cmsio2.rc.ufl.edu:1094/store/user/bockjoo/archive_${SITE}.tgz ; )
[ -e ${SYNC_DIR}/SITECONF/${SITE} ] && \
    { \
      echo Warning ${SYNC_DIR}/SITECONF/${SITE} exists
           status=$(/bin/rm -rf ${SYNC_DIR}/SITECONF/${SITE} > /dev/null 2>&1 ; echo $?) ; \
           [ $status -eq 0 ] || { echo ERROR removing ${SYNC_DIR}/SITECONF/${SITE} failed ; } ; \
           /bin/touch ${SYNC_DIR}/SITECONF/.timestamp ; \
           /bin/sed -i "/^${SITE}:/d" ${SYNC_DIR}/SITECONF/.timestamp ; \
      } ;
      status=$(/bin/mv ${SYNC_DIR}/SITECONF/${TAR_DIR} ${SYNC_DIR}/SITECONF/${SITE} > /dev/null 2>&1 ; echo $?)
      [ $status -eq 0 ] || { echo ERROR failed to move area of $SITE ; exit 1 ; } ;
      list_sites_updated="$list_sites_updated $SITE"
   
   echo "   updating CVMFS timestamp of site for $SITE"
   status=$(/bin/touch ${SYNC_DIR}/SITECONF/.timestamp > /dev/null 2>&1 ; echo $?)
   status=$(/bin/sed -i "/^${SITE}:/d" ${SYNC_DIR}/SITECONF/.timestamp > /dev/null 2>&1 ; echo $(expr $status + $?) ; )
   status=$(/usr/bin/awk -F: '{if($1=="'${SITE}'"){print $0}}' ${TMP_AREA}/.timestamp >> ${SYNC_DIR}/SITECONF/.timestamp 2>/dev/null ; echo $(expr $status + $?) ; )
   [ $status -eq 0 ] || { echo ERROR status is not 0 ; exit 0 ; } ;
# Check if there was any siteconf that is updated
sites_cvmfs=$(ls /cvmfs/cms.cern.ch/SITECONF | sort -u | grep T[0-9])
sites_sync_dir=$(ls $SYNC_DIR/SITECONF | sort -u | grep T[0-9])
   
for s in $sites_cvmfs ; do
    status=$(for s_sync in $sites_sync_dir ; do echo $s_sync ; done | grep -q $s ; echo $?)
    [ $status -eq 0 ] && continue
    echo DEBUG $s REMOVED from gitlab or sitedb
    status=$(for s_u in $list_sites_updated ; do echo $s_u ; done | grep -q $s ; echo $?)
    [ $status -eq 0 ] || list_sites_updated="$list_sites_updated $s"
done
export UPDATED_SITES="$(echo $list_sites_updated)"
echo UPDATED_SITES=$UPDATED_SITES
if [ ! -f cron_install_cmssw.lock ] ; then
    date > cron_install_cmssw.lock 
    cvmfs_server transaction
    echo INFO cvmfs_server transaction $?
fi
if [ -d ${SYNC_DIR}/SITECONF/${SITE} ] ; then
   #rsync -arzuvp --exclude=.cvmfscatalog --delete ${SYNC_DIR}/SITECONF/ $RSYNC_SITES
   rsync -arzuvp --exclude=.cvmfscatalog --delete ${SYNC_DIR}/SITECONF/${SITE} $RSYNC_SITES/

   cvmfs_server publish
   rm -f cron_install_cmssw.lock
fi
