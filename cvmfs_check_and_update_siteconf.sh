#!/bin/sh
# #############################################################################
# cvmfs_update.sh   Simple script to keep a SYNC_DIR area up-to-date with
#                   config files for jobs from the SITECONF repository.
#                   Script aquires a lock to prevent multiple, simultaneous
#                   executions; queries SiteDB for a list of CMS sites; fetches
#                   the commit information from the SITECONF GitLab repository;
#                   removes sites in SYNC_DIR no longer in SiteDB; updates job
#                   config files for sites where the files got updated;
#
#                   Please configure the SYNC_DIR, TMP_AREA (for temporary
#                   files during script execution), AUTH_CRT, AUTH_KEY (pem
#                   files with your cert/key), AUTH_TKN (your token in GitLab),
#                   and EMAIL_ADDR (in case of errors) before execution.
# Created by Stephan Lammel
# Developed by Bockjoo Kim to use it for the cvmfs
# Revision
# versions Description
# 0.1      Original
# 0.2      Add more debug
# 0.3      Use date command to calculate epochs timestamp
# version=0.3
# 
# #############################################################################
# Versions
# 1.8.7

# Configuration
version=1.8.7
notifytowhom=bockjoo@phys.ufl.edu
updated_list=/cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates
what="$(basename $0)"
RSYNC_SITES="/cvmfs/cms.cern.ch/SITECONF"   # /cvmfs/cms.cern.ch/SITECONF
SKIP_SITES="T3_US_ANL"
EXC_LOCK=""
TMP_AREA="/tmp/cvmfs_tmp"
ERR_FILE="/tmp/stcnf_$$.err"
EVERY_X_HOUR=4
siteconf_cat=https://gitlab.cern.ch/api/v4/groups/4099/projects # See https://cern.service-now.com/service-portal/view-request.do?n=RQF1526910 
siteid_list=$HOME/siteid_list.txt
SYNC_DIR="$HOME/SITECONF"         # /cvmfs/cms.cern.ch
AUTH_TKN="$(cat $HOME/.AUTH_TKN)" # private token $HOME/.AUTH_TKN
EMAIL_ADDR="$notifytowhom"        # your email
export X509_USER_PROXY=$HOME/.florida.t2.proxy
AUTH_CRT="$X509_USER_PROXY"
AUTH_KEY="$X509_USER_PROXY"

source $HOME/cron_install_cmssw.config # notifytowhom
source $HOME/functions-cms-cvmfs-mgmt

# update proxy
source /home/cvcms/osg/osg-wn-client/setup.sh
globus-url-copy -vb gsiftp://cmsio.rc.ufl.edu/cmsuf/t2/operations/.cmsphedex.proxy  file://$X509_USER_PROXY.copy
if [ $? -eq 0 ] ; then
   cp $X509_USER_PROXY.copy $X509_USER_PROXY
   voms-proxy-info -all
else
   if [ $(voms-proxy-info -timelef 2>/dev/null) -lt 100 ] ; then
      printf "$what ERROR failed to download $X509_USER_PROXY\n$(globus-url-copy -vb gsiftp://cmsio.rc.ufl.edu/cmsuf/t2/operations/.cmsphedex.proxy  file://$X509_USER_PROXY.copy 2>&1 | sed 's#%#%%#g')n" | mail -s "$what ERROR proxy download failed" $notifytowhom
      exit 1
   fi
   echo INFO using previous one
   voms-proxy-info -all
fi

# AUTH Token for gitlab siteconf api access 
if [ ! -f $HOME/.AUTH_TKN ] ; then
   printf "$what ERROR  $HOME/.AUTH_TKN does not exist \n" | mail -s "$what ERROR No Auth Token Found" $notifytowhom
   exit 1
fi


echo DEBUG TMP_AREA=$TMP_AREA
trap 'exit 1' 1 2 3 15
trap '(/bin/rm -rf ${EXC_LOCK} ${TMP_AREA} ${ERR_FILE}) 1> /dev/null 2>&1' 0


echo "[0] SYNC_DIR=$SYNC_DIR"
# #############################################################################



# get cvmfs/stcnf_updt lock:
# --------------------------
echo "[1] Acquiring lock for cvmfs/stcnf_updt"
if [ ! -d /var/tmp/cvmfs ]; then
   /bin/rm -rf /var/tmp/cvmfs 1>/dev/null 2>&1
   /bin/mkdir /var/tmp/cvmfs 1>/dev/null 2>&1
fi
/bin/ln -s $$ /var/tmp/cvmfs/stcnf_updt.lock
if [ $? -ne 0 ]; then
   # locking failed, get lock information
   LKINFO=`/bin/ls -il /var/tmp/cvmfs/stcnf_updt.lock 2>/dev/null`
   LKFID=`echo ${LKINFO} | /usr/bin/awk '{print $1; exit}' 2>/dev/null`
   LKPID=`echo ${LKINFO} | /usr/bin/awk '{print $NF;exit}' 2>/dev/null`
   # check process holding lock is still active
   /bin/ps -fp ${LKPID} 1>/dev/null 2>&1
   if [ $? -eq 0 ]; then
      echo "   active process ${LKPID} holds lock, exiting"
      exit 1
   fi
   echo "   removing leftover lock: ${LKINFO}"
   /usr/bin/find /var/tmp/cvmfs -inum ${LKFID} -exec /bin/rm -f {} \;
   LKPID=""
   LKFID=""
   LKINFO=""
   #
   /bin/ln -s $$ /var/tmp/cvmfs/stcnf_updt.lock
   if [ $? -ne 0 ]; then
      echo "   failed to acquire lock, exiting"
      exit 1
   fi
fi

# double check we have the lock
LKPID=`(/bin/ls -l /var/tmp/cvmfs/stcnf_updt.lock | /usr/bin/awk '{if($(NF-1)=="->")print $NF;else print "";exit}') 2>/dev/null`
if [ "${LKPID}" != "$$" ]; then
   echo "   lost lock to process ${LKPID}, exiting"
   exit 1
fi
LKPID=""
EXC_LOCK="/var/tmp/cvmfs/stcnf_updt.lock"
# #############################################################################


# Try to create a temporary directory
/bin/rm -f ${ERR_FILE} 1>/dev/null 2>&1
/bin/rm -rf ${TMP_AREA} 1>/dev/null 2>&1
/bin/mkdir ${TMP_AREA} 1>${ERR_FILE} 2>&1
RC=$?
if [ ${RC} -ne 0 ]; then
   MSG="failed to create TMP_AREA, mkdir=${RC}"
   /bin/cat ${ERR_FILE}
   echo "   ${MSG}"
   if [ ! -t 0 ]; then
      printf "$0 ${MSG}\n$(cat ${ERR_FILE})\n" | mail -s "$0 ${MSG}" $notifytowhom # /usr/bin/Mail -s "$0 ${MSG}" ${EMAIL_ADDR} < ${ERR_FILE}
   fi
   exit ${RC}
fi
/bin/rm -f ${ERR_FILE} 1>/dev/null 2>&1

# Create $SYNC_DIR if needed
if [ ! -d ${SYNC_DIR} ]; then
   echo INFO doing /bin/mkdir -p ${SYNC_DIR} at $(pwd)
   /bin/mkdir -p ${SYNC_DIR} 1>${ERR_FILE} 2>&1
   RC=$?
   if [ ${RC} -ne 0 ]; then
      MSG="failed to create SYNC_DIR, mkdir=${RC}"
      /bin/cat ${ERR_FILE}
      echo "   ${MSG}"
      if [ ! -t 0 ]; then
         printf "$0 ${MSG}\n$(cat ${ERR_FILE})\n" | mail -s "$0 ${MSG}" $notifytowhom # /usr/bin/Mail -s "$0 ${MSG}" ${EMAIL_ADDR} < ${ERR_FILE}
      fi
      exit ${RC}
   fi
fi

# Create SITECONF if needed
/bin/rm -f ${ERR_FILE} 1>/dev/null 2>&1
if [ ! -d ${SYNC_DIR}/SITECONF ]; then
   /bin/mkdir ${SYNC_DIR}/SITECONF 1>${ERR_FILE} 2>&1
   RC=$?
   if [ ${RC} -ne 0 ]; then
      MSG="failed to create SYNC_DIR/SITECONF, mkdir=${RC}"
      /bin/cat ${ERR_FILE}
      echo "   ${MSG}"
      if [ ! -t 0 ]; then
         printf "$0 ${MSG}\n$(cat ${ERR_FILE})\n" | mail -s "$0 ${MSG}" $notifytowhom # /usr/bin/Mail -s "$0 ${MSG}" ${EMAIL_ADDR} < ${ERR_FILE}
      fi
      exit ${RC}
   fi
fi
/bin/rm -f ${ERR_FILE} 1>/dev/null 2>&1

# get list of CMS sites:
# ======================
echo "[2] Fetching list of CMS sites..."
SITES_URL="https://cmsweb.cern.ch/sitedb/data/prod/site-names"
/bin/rm -f ${TMP_AREA}/sitedb.json 1>/dev/null 2>&1
/usr/bin/curl -L -k --key $AUTH_CRT --cert $AUTH_CRT -v "http://cms-cric.cern.ch/api/cms/site/query/?json&preset=site-names&rcsite_state=ANY" 1>${TMP_AREA}/sitedb.json 2>${ERR_FILE}
RC=$?
# for now use the static sitedb.json
if [ $RC -ne 0  ] ; then
   echo DEBUG doing /bin/cp $HOME/sitedb.json ${TMP_AREA}/sitedb.json
   /bin/cp $HOME/sitedb.json ${TMP_AREA}/sitedb.json
   RC=$?
fi
if [ ${RC} -ne 0 ]; then
   MSG="failed to query SiteDB to get site-names, curl=${RC}"
   /bin/cat ${ERR_FILE}
   echo "   ${MSG}"
   if [ ! -t 0 ]; then
      printf "$0 ${MSG}\n$(cat ${ERR_FILE})\n" | mail -s "$0 ${MSG}" $notifytowhom # /usr/bin/Mail -s "$0 ${MSG}" ${EMAIL_ADDR} < ${ERR_FILE}
   fi
   exit ${RC}
fi
/bin/rm ${ERR_FILE} 1>/dev/null 2>&1


# make list of CMS site names:
/bin/rm -f ${TMP_AREA}/sitedb.list
grep \"T[0-9]  ${TMP_AREA}/sitedb.json | cut -d\" -f2 | sort -u > ${TMP_AREA}/sitedb.list
/bin/rm ${TMP_AREA}/sitedb.json

# sanity check of SiteDB sites:
if [ $(/usr/bin/awk 'BEGIN{nl=0}{nl+=1}END{print nl}' ${TMP_AREA}/sitedb.list 2>/dev/null) -lt 100 ]; then
   MSG="sanity check of SiteDB sites failed, exiting"
   echo "   ${MSG}"
   if [ ! -t 0 ]; then
      printf "$0 ${MSG}\n$(cat ${TMP_AREA}/sitedb.list)\n" | mail -s "$0 ${MSG}" $notifytowhom # echo "${SDB_LIST}" | /usr/bin/Mail -s "$0 ${MSG}" ${EMAIL_ADDR}
   fi
   exit 1
fi
if [ $(/bin/grep '^T0_' ${TMP_AREA}/sitedb.list 2>/dev/null | /usr/bin/wc -l) -lt 1 ]; then
   MSG="sanity check of SiteDB Tier-0 count failed, exiting"
   echo "   ${MSG}"
   if [ ! -t 0 ]; then
      printf "$0 ${MSG}\n$(cat ${TMP_AREA}/sitedb.list)\n" | mail -s "$0 ${MSG}" $notifytowhom # echo "${SDB_LIST}" | /usr/bin/Mail -s "$0 ${MSG}" ${EMAIL_ADDR}
   fi
   exit 1
fi
if [ $(/bin/grep '^T1_' ${TMP_AREA}/sitedb.list 2>/dev/null | /usr/bin/wc -l) -lt 5 ]; then
   MSG="sanity check of SiteDB Tier-1 count failed, exiting"
   echo "   ${MSG}"
   if [ ! -t 0 ]; then
      printf "$0 ${MSG}\n$(cat ${TMP_AREA}/sitedb.list)\n" | mail -s "$0 ${MSG}" $notifytowhom # echo "${SDB_LIST}" | /usr/bin/Mail -s "$0 ${MSG}" ${EMAIL_ADDR}
   fi
   exit 1
fi
if [ $(/bin/grep '^T2_' ${TMP_AREA}/sitedb.list 2>/dev/null | /usr/bin/wc -l) -lt 40 ]; then
   MSG="sanity check of SiteDB Tier-2 count failed, exiting"
   echo "   ${MSG}"
   if [ ! -t 0 ]; then
      printf "$0 ${MSG}\n$(cat ${TMP_AREA}/sitedb.list)\n" | mail -s "$0 ${MSG}" $notifytowhom # echo "${SDB_LIST}" | /usr/bin/Mail -s "$0 ${MSG}" ${EMAIL_ADDR}
   fi
   exit 1
fi
if [ $(/bin/grep '^T3_' ${TMP_AREA}/sitedb.list 2>/dev/null | /usr/bin/wc -l) -lt 50 ]; then
   MSG="sanity check of SiteDB Tier-3 count failed, exiting"
   echo "   ${MSG}"
   if [ ! -t 0 ]; then
      printf "$0 ${MSG}\n$(cat ${TMP_AREA}/sitedb.list)\n" | mail -s "$0 ${MSG}" $notifytowhom # echo "${SDB_LIST}" | /usr/bin/Mail -s "$0 ${MSG}" ${EMAIL_ADDR}
   fi
   exit 1
fi
# #############################################################################



# get list of GitLab projects (CMS sites) with last update time:
# ==============================================================
echo "[3] Fetching list of GitLab projects/sites..."
/bin/cp /dev/null ${ERR_FILE} 1>/dev/null 2>&1
SUCC=0
FAIL=0
for PAGE in 1 2 3 4 5 6 7 8 9; do
   /usr/bin/wget --header="PRIVATE-TOKEN: ${AUTH_TKN}" --read-timeout=90 -O ${TMP_AREA}/gitlab_${PAGE}.json 'https://gitlab.cern.ch/api/v4/groups/SITECONF/projects?per_page=100&page='${PAGE} 1>>${ERR_FILE} 2>&1
   RC=$?
   echo DEBUG gitlab page:
   if [ ${RC} -eq 0 ]; then
      SUCC=1
      /bin/grep name ${TMP_AREA}/gitlab_${PAGE}.json 1>/dev/null 2>&1
      if [ $? -ne 0 ]; then
         break
      fi
      echo DEBUG gitlab_${PAGE}.json PAGE=$PAGE OK
   else
      FAIL=1
      MSG="failed to query GitLab projects, page ${PAGE}, wget=${RC}"
      echo "   ${MSG}"
      if [ ! -t 0 ]; then
         echo "${MSG}" >> ${ERR_FILE}
         echo "" >> ${ERR_FILE}
      fi
      echo DEBUG gitlab_${PAGE}.json PAGE=$PAGE FAIL
   fi
done
if [ ${FAIL} -ne 0 ]; then
   MSG="failed to query GitLab projects"
   echo ""
   /bin/cat ${ERR_FILE}
   echo "   ${MSG}"
   if [ ! -t 0 ]; then
      printf "$(/bin/hostname) $0: ${MSG}\n$(cat ${ERR_FILE})" | mail -s "ERROR: $MSG" $notifytowhom
   fi
fi
if [ ${SUCC} -eq 0 ]; then
   exit 1
fi
/bin/rm ${ERR_FILE} 1>/dev/null 2>&1
# ###################################################################################################

/bin/rm -f ${TMP_AREA}/.timestamp
sed 's#"name":"T#\n"name":"T#g' ${TMP_AREA}/gitlab_[0-9]*.json | grep last_activity_at | \
while read line ; do 
      site_last_activity=$(echo $line | sed 's#,#^\n#g' | grep "\"name\":\"T\|last_activity_at")
      site=$(echo $site_last_activity | cut -d\^ -f1 | cut -d: -f2 | sed 's#"##g')
      timestamp=$(echo $site_last_activity | cut -d\^ -f2 | cut -d: -f2- | cut -d. -f1 | sed 's#"##g')
      timestamp=$(date -d "$timestamp" +%s)
      echo $site:$timestamp
done > ${TMP_AREA}/.timestamp

# ${TMP_AREA}/.timestamp should not be empty
if [ $(cat ${TMP_AREA}/.timestamp | wc -l) -lt 100 ] ; then
   echo ERROR ${TMP_AREA}/.timestamp has less than 100 entries
   printf "$(/bin/hostname) $0: ${TMP_AREA}/.timestamp has less than 100 entries\n$(cat ${TMP_AREA}/.timestamp)\n" | mail -s "ERROR: Content of ${TMP_AREA}/.timestamp" $notifytowhom
   # release thelock:
   echo "Releasing lock for cvmfs/stcnf_updt"
   /bin/rm ${EXC_LOCK}
   EXC_LOCK=""
   exit 0
fi

/bin/rm ${TMP_AREA}/gitlab_*.json
# #############################################################################

echo "[4] loop over SYNC_DIR ${SYNC_DIR} CMS sites and remove sites no longer in SiteDB..."
# loop over SYNC_DIR CMS sites and remove sites no longer in SiteDB:
# ==================================================================
/bin/cp /dev/null ${ERR_FILE} 1>/dev/null 2>&1
FAIL=0
SYNC_LIST=$(cd ${SYNC_DIR}/SITECONF ; /bin/ls -d1 T?_??_* 2>/dev/null)
for SITE in ${SYNC_LIST}; do
   #echo DEBUG site=$SITE checking /bin/grep "^${SITE}\$" ${TMP_AREA}/sitedb.list
   /bin/grep "^${SITE}\$" ${TMP_AREA}/sitedb.list 1>/dev/null 2>&1
   if [ $? -ne 0 ]; then
      echo "Site \"${SITE}\" no longer in SiteDB, removing site area"
      /bin/rm -rf ${SYNC_DIR}/SITECONF/${SITE} 1>>${ERR_FILE} 2>&1
      RC=$?
      if [ ${RC} -ne 0 ]; then
         FAIL=1
         MSG="failed to remove area of ${SITE} not in SiteDB, rm=${RC}"
         echo "   ${MSG}"
         if [ ! -t 0 ]; then
            echo "${MSG}" >> ${ERR_FILE}
            echo "" >> ${ERR_FILE}
         fi
      fi
      /bin/rm ${ERR_FILE} 1>/dev/null 2>&1
      #
      /bin/touch ${SYNC_DIR}/SITECONF/.timestamp
      /bin/sed -i "/^${SITE}:/d" ${SYNC_DIR}/SITECONF/.timestamp
   fi
done
if [ ${FAIL} -ne 0 ]; then
   MSG="failed to remove areas not in SiteDB"
   echo ""
   /bin/cat ${ERR_FILE}
   echo "   ${MSG}"
   if [ ! -t 0 ]; then
      printf "$0 ${MSG}\n$(cat ${ERR_FILE})\n" | mail -s "$0 ${MSG}" $notifytowhom # /usr/bin/Mail -s "$0 ${MSG}" ${EMAIL_ADDR} < ${ERR_FILE}
   fi
   /bin/rm ${EXC_LOCK}
   exit 1
fi
/bin/rm ${ERR_FILE} 1>/dev/null 2>&1
# #############################################################################



echo "[5] loop over CRIC sites and update SYNC_DIR as needed"
# loop over SiteDB sites and update SYNC_DIR as needed:
# =====================================================
/bin/cp /dev/null ${ERR_FILE} 1>/dev/null 2>&1
list_sites_updated=""
FAIL=0
isite=0


ipages=0
status=0
while [ $ipages -lt 100 ] ; do
   ipages=$(expr $ipages + 1)
   /usr/bin/wget -q --header="PRIVATE-TOKEN: ${AUTH_TKN}" --read-timeout=180 -O ${TMP_AREA}/siteconf_cat.${ipages} "$siteconf_cat?page=${ipages}&per_page=100" 2>&1
  status=$(expr $status + $?)
  [ $status -eq 0 ] || break
  # If we can not find .git in the page, the page is empty or something
  grep -q \\.git ${TMP_AREA}/siteconf_cat.${ipages}
  [ $? -eq 0 ] || { rm -f ${TMP_AREA}/siteconf_cat.${ipages} ; break ; } ;
  echo INFO check ${TMP_AREA}/siteconf_cat.${ipages}
done
if [ $status -ne 0 ] ; then
   printf "$(/bin/hostname) $0 failed to download one of the pages in $siteconf_cat\nUsing /usr/bin/wget --header=\"PRIVATE-TOKEN: \$(cat \$AUTH_TKN)\" --read-timeout=180 -O ${TMP_AREA}/siteconf_cat $siteconf_cat " | mail -s "ERROR: wget $siteconf_cat AUTH failed " $notifytowhom
   /bin/rm ${EXC_LOCK}
   exit 1
fi

# Just in case, create a cache for siteid_list
printf "$(cat ${TMP_AREA}/siteconf_cat*)\n" | sed 's#"name":"siteconf"#\n"name":"siteconf"#g' | grep -i siteconf/.*.git | sed 's#,#\n#g' | grep "^{\"id" | cut -d: -f2 | \
while read id ; do
  siteconf_sitename=$(printf "$(cat ${TMP_AREA}/siteconf_cat*)\n" | sed 's#"name":"siteconf"#\n"name":"siteconf"#g' | grep -i siteconf/.*.git | sed 's#,#\n#g' | grep -A 2 "^{\"id\":$id" | grep \"name\": | cut -d\" -f4)
  echo "$siteconf_sitename" | grep -q ^T
  [ $? -eq 0 ] || { echo Warning $siteconf_sitename does not start with 'T' ; continue ; } ;
  grep -q "$siteconf_sitename $id" $siteid_list
  [ $? -eq 0 ] || { echo INFO adding  "$siteconf_sitename $id" to $siteid_list ; echo "$siteconf_sitename $id" >> $siteid_list ; } ;
done

# Sanity check for the downloaded output
grep -q '"name":"siteconf"' ${TMP_AREA}/siteconf_cat*
if [ $? -ne 0 ] ; then
   printf "$(/bin/hostname) $0 failed to download $siteconf_cat\nUsing /usr/bin/wget --header=\"PRIVATE-TOKEN: \$(cat \$AUTH_TKN)\" --read-timeout=180 -O ${TMP_AREA}/siteconf_cat $siteconf_cat \n${TMP_AREA}/siteconf_cat wrong" | mail -s "ERROR: wget $siteconf_cat ${TMP_AREA}/siteconf_cat wrong " $notifytowhom
   /bin/rm ${EXC_LOCK}
   exit 1
fi

# Compare the new timestamp ($NEWT) with the old ($OLDT). If they are different, download the siteconf for the site (given the siteid)
for SITE in $(/bin/cat ${TMP_AREA}/sitedb.list) ; do
   isite=$(expr $isite + 1)
   #echo "[5]" DEBUG doing SITE=$SITE
   NEWT=`/usr/bin/awk -F: '{if($1=="'${SITE}'"){print $2}}' ${TMP_AREA}/.timestamp 2>/dev/null`
   if [ -z "${NEWT}" ]; then
      # no repository for this SiteDB site
      #echo DEBUG SITE=$SITE no repository for this SiteDB site. Continuing...      
      continue
   fi
   if [ -f ${SYNC_DIR}/SITECONF/.timestamp ]; then
      OLDT=`/usr/bin/awk -F: '{if($1=="'${SITE}'"){print $2}}' ${SYNC_DIR}/SITECONF/.timestamp 2>/dev/null`
      if [ "${NEWT}" == "${OLDT}" ]; then
         # SYNC_DIR up-to-date
         #echo DEBUG SITE=$SITE SYNC_DIR up-to-date. Continuing... OLDT=$OLDT NEWT=$NEWT
         #
         # 02APR2018
         # timestamp in https://gitlab.cern.ch/api/v3/groups/SITECONF/projects?per_page=100&page=1
         # is not fine-grained. If the change happens in less than 5 minutes, the timestamp does not change
         # so I am ignoring timestamp-based update every four hour.
         # every four hour all sites that changed are updated
         #
         if [ $(expr $(date +%H) % $EVERY_X_HOUR) -eq 0 ] ; then
            echo INFO "[ $isite ]" SITE=$SITE HOUR=$(date +%H) so ignore timestamp for once and update the siteconf 2>/dev/null 1>/dev/null
         else
            echo INFO "[ $isite ]" SITE=$SITE timestamp is same. Skipping this site 2>/dev/null 1>/dev/null
            continue
         fi
      fi
   fi

   #
   # need to update SITECONF:
   # ------------------------
   echo "[5-1] Updating area of site \"${SITE}\":"
   UPPER=`echo ${SITE} | /usr/bin/tr '[:lower:]' '[:upper:]'`
   thesiteid=$(printf "$(cat ${TMP_AREA}/siteconf_cat.*)\n" | sed 's#"name":"siteconf"#\n"name":"siteconf"#g' | grep -i siteconf/${UPPER}.git | sed 's#,#\n#g' | grep "^{\"id" | cut -d: -f2)
   # The pagination for siteconf_cat does not work from time to time, use the siteid from the cache
   if [ "x$thesiteid" == "x" ] ; then
      thesiteid=$(grep "${SITE} " $siteid_list 2>/dev/null | awk '{print $2}')
   fi

   echo "[5-2] Site id for \"${SITE}\":${thesiteid}:"
   if [ "x$thesiteid" == "x" ] ; then
         /bin/cp ${TMP_AREA}/siteconf_cat.* $HOME/
         printf "$(/bin/hostname) $0  ERROR: the site id is empty for $SITE. This should not have happened\n" | mail -s "ERROR:  the site id empty with $SITE" $notifytowhom
         continue
   fi
   /usr/bin/wget --header="PRIVATE-TOKEN: $(cat .AUTH_TKN)" --read-timeout=180 -O ${TMP_AREA}/archive_${SITE}.tgz https://gitlab.cern.ch/api/v4/projects/${thesiteid}/repository/archive.tar.gz?ref=master
   RC=$?
   if [ ${RC} -ne 0 ]; then
      /usr/bin/wget --header="PRIVATE-TOKEN: $(cat .AUTH_TKN)" --read-timeout=180 -O ${TMP_AREA}/archive_${SITE}.tgz https://gitlab.cern.ch/api/v4/projects/${thesiteid}/repository/archive.tar.gz?ref=master 2>&1 | grep -q "Authorization failed"
      if [ $? -eq 0 ] ; then
         echo ERROR: wget Authorization failed with $SITE. This should not have happened
         printf "$(/bin/hostname) $0  ERROR: wget Authorization failed with $SITE. This should not have happened\n" | mail -s "ERROR:  wget Authorization failed with $SITE" $notifytowhom
         continue
      fi
      FAIL=1
      MSG="failed to fetch GitLab archive of ${SITE}, wget=${RC}"
      echo "   ${MSG}"
      if [ ! -t 0 ]; then
         echo "${MSG}" >> ${ERR_FILE}
         echo "" >> ${ERR_FILE}
      fi
      printf "$(/bin/hostname) $0  Warning: failed to fetch GitLab archive of ${SITE} SiteId=$thesiteid , wget=${RC}\n/usr/bin/wget --header=\"PRIVATE-TOKEN: \$(cat \$AUTH_TKN)\" --read-timeout=180 -O ${TMP_AREA}/archive_${SITE}.tgz https://gitlab.cern.ch/api/v4/projects/${thesiteid}/repository/archive.tar.gz?ref=master\n" | mail -s "Warning:  wget FAIL with $SITE" $notifytowhom
      continue
   fi
   
   tar tzvf ${TMP_AREA}/archive_${SITE}.tgz | grep -q -i ${SITE}-
   if [ $? -ne 0 ] ; then
      FAIL=1
      MSG="failed to pass tar tzvf ${TMP_AREA}/archive_${SITE}.tgz for $SITE"
      echo "${MSG}" >> ${ERR_FILE}
      echo "" >> ${ERR_FILE}
      printf "$(/bin/hostname) $0  Warning: failed to pass tar tzvf ${TMP_AREA}/archive_${SITE}.tgz | grep -q -i $SITE\n$(tar tzvf ${TMP_AREA}/archive_${SITE}.tgz)\n" | mail -s "Warning:  wget FAIL with $SITE Wrong download" $notifytowhom
      continue
   fi
   
   TAR_DIR=`(/bin/tar -tzf ${TMP_AREA}/archive_${SITE}.tgz | /usr/bin/awk -F/ '{print $1;exit}') 2>/dev/null`
   TAR_LST=`(/bin/tar -tzf ${TMP_AREA}/archive_${SITE}.tgz | /usr/bin/awk -F/ '{if((($2=="JobConfig")&&(match($3,".*site-local-config.*\\.xml$")!=0))||(($2=="JobConfig")&&(match($3,"^cmsset_.*\\.c?sh$")!=0))||(($2=="PhEDEx")&&(match($3,".*storage.*\\.xml$")!=0))||(($2=="Tier0")&&($3=="override_catalog.xml"))||(($2=="GlideinConfig")&&($3=="")))print $0}') 2>/dev/null`
   
   # 17JUL2018 forget about sites that do not have xml files in the gitlab
   if [ -s ${TMP_AREA}/archive_${SITE}.tgz ] ; then
      tar tzvf ${TMP_AREA}/archive_${SITE}.tgz 2>&1 | grep -q xml
      if [ $? -ne 0 ] ; then
         echo "   Warning: ${TMP_AREA}/archive_${SITE}.tgz does not have config files not extracting tar archive"
         continue
      fi
   fi
   if [ -n "${TAR_LST}" ]; then
      echo "   extracting tar archive"
      (cd ${SYNC_DIR}/SITECONF; /bin/tar -xzf ${TMP_AREA}/archive_${SITE}.tgz ${TAR_LST}) 1>>${ERR_FILE} 2>&1
   else
      if [ "x$(echo ${TAR_DIR})" != "x" ] ; then
         /bin/mkdir ${SYNC_DIR}/SITECONF/${TAR_DIR}
         /bin/mkdir ${SYNC_DIR}/SITECONF/${TAR_DIR}/JobConfig
      fi
   fi
   RC=$?
   if [ ${RC} -ne 0 ]; then
      FAIL=1
      MSG="failed to extract tar archive of ${SITE}, tar=${RC}"
      echo "   ${MSG}"
      if [ ! -t 0 ]; then
         echo "${MSG}" >> ${ERR_FILE}
         echo "" >> ${ERR_FILE}
         /bin/rm ${TMP_AREA}/archive_${SITE}.tgz
      fi
      continue
   fi
   /bin/rm ${TMP_AREA}/archive_${SITE}.tgz
   
   # avoid directory file update in case extracted files did not change
   /usr/bin/diff -r ${SYNC_DIR}/SITECONF/${SITE} ${SYNC_DIR}/SITECONF/${TAR_DIR} 1>/dev/null 2>&1
   status=$?
   echo DEBUG status=$status checking /usr/bin/diff -r ${SYNC_DIR}/SITECONF/${SITE} ${SYNC_DIR}/SITECONF/${TAR_DIR}
   /usr/bin/diff -r ${SYNC_DIR}/SITECONF/${SITE} ${SYNC_DIR}/SITECONF/${TAR_DIR}
   if [ "$SITE" == "T2_CH_CERN_HLT" ] ; then
      echo cat ${SYNC_DIR}/SITECONF/${SITE}/JobConfig/site-local-config.xml 
      cat ${SYNC_DIR}/SITECONF/${SITE}/JobConfig/site-local-config.xml 
      echo cat ${SYNC_DIR}/SITECONF/${TAR_DIR}JobConfig/site-local-config.xml 
      cat ${SYNC_DIR}/SITECONF/${TAR_DIR}JobConfig/site-local-config.xml 
   fi
   if [ $status -eq 0 ]; then
      # no file difference, keep old area
      echo "   no change to CVMFS files, keeping old area"
      /bin/rm -rf ${SYNC_DIR}/SITECONF/${TAR_DIR} 1>>${ERR_FILE} 2>&1
      RC=$?
      if [ ${RC} -ne 0 ]; then
         FAIL=1
         MSG="failed to remove new area of ${SITE}, rm=${RC}"
         echo "   ${MSG}"
         if [ ! -t 0 ]; then
            echo "${MSG}" >> ${ERR_FILE}
            echo "" >> ${ERR_FILE}
         fi
      fi
   else
      #
      if [ -e ${SYNC_DIR}/SITECONF/${SITE} ]; then
         echo "   removing old CVMFS area"
         /bin/rm -rf ${SYNC_DIR}/SITECONF/${SITE} 1>>${ERR_FILE} 2>&1
         RC=$?
         if [ ${RC} -ne 0 ]; then
            FAIL=1
            MSG="failed to remove old area of ${SITE}, rm=${RC}"
            echo "   ${MSG}"
            if [ ! -t 0 ]; then
               echo "${MSG}" >> ${ERR_FILE}
               echo "" >> ${ERR_FILE}
               /bin/rm -rf ${SYNC_DIR}/SITECONF/${TAR_DIR}
            fi
            continue
         fi
         /bin/touch ${SYNC_DIR}/SITECONF/.timestamp
         /bin/sed -i "/^${SITE}:/d" ${SYNC_DIR}/SITECONF/.timestamp
      fi
      #
      echo "   moving tar area into place"
      /bin/mv ${SYNC_DIR}/SITECONF/${TAR_DIR} ${SYNC_DIR}/SITECONF/${SITE} 1>>${ERR_FILE} 2>&1
      if [ $? -ne 0 ]; then
         # this is bad, so we better re-try:
         /bin/sync
         /bin/sleep 3
         echo "   re-trying move of ${SITE} area" >> ${ERR_FILE}
         /bin/mv ${SYNC_DIR}/SITECONF/${TAR_DIR} ${SYNC_DIR}/SITECONF/${SITE} 1>>${ERR_FILE} 2>&1
      fi
      RC=$?
      if [ ${RC} -ne 0 ]; then
         FAIL=1
         MSG="failed to move area of ${SITE}, mv=${RC}"
         echo "   ${MSG}"
         if [ ! -t 0 ]; then
            echo "${MSG}" >> ${ERR_FILE}
            echo "" >> ${ERR_FILE}
            /bin/rm -rf ${SYNC_DIR}/SITECONF/${TAR_DIR}
         fi
         continue
      fi
      list_sites_updated="$list_sites_updated $SITE"
   fi
   #
   echo "   updating CVMFS timestamp of site"
   /bin/touch ${SYNC_DIR}/SITECONF/.timestamp
   /bin/sed -i "/^${SITE}:/d" ${SYNC_DIR}/SITECONF/.timestamp 1>/dev/null 2>&1
   /usr/bin/awk -F: '{if($1=="'${SITE}'"){print $0}}' ${TMP_AREA}/.timestamp >> ${SYNC_DIR}/SITECONF/.timestamp
done
if [ ${FAIL} -ne 0 ]; then
   MSG="failed to update SITECONF in SYNC_DIR"
   echo ""
   /bin/cat ${ERR_FILE}
   echo "   ${MSG}"
   if [ ! -t 0 ]; then
      printf "$(/bin/hostname) $0: ${MSG}\n$(cat ${ERR_FILE})" | mail -s "ERROR: $MSG" $notifytowhom
   fi
   /bin/rm ${EXC_LOCK}
   exit 1
fi

#
# if there are sites that are removed from gitlab or sitedb and UPDATE_SITES is empty,
# we need to make sure those sites are deleted from /cvmfs/cms.cern.ch/SITECONF and those
# sites should be added to the UPDATED_SITES list
#
# Ensure the $HOME/SITECONF/SITECONF has some content
if [ $(ls $SYNC_DIR/SITECONF 2>/dev/null | wc -l) -le 1 ] ; then
      echo ERROR $SYNC_DIR/SITECONF empty
      printf "ERROR $what $SYNC_DIR/SITECONF empty\nls $SYNC_DIR/SITECONF\necho INFO probably execute this command: rsync -arzuvp --exclude=.cvmfscatalog --delete ${RSYNC_SITES} $SYNC_DIR/" | mail -s "ERROR: $what $SYNC_DIR/SITECONF empty" $notifytowhom      
      exit 1
fi

# Check if there was any siteconf that is updated
sites_cvmfs=$(ls /cvmfs/cms.cern.ch/SITECONF | sort -u | grep T[0-9])
sites_sync_dir=$(ls $SYNC_DIR/SITECONF | sort -u | grep T[0-9])
   
for s in $sites_cvmfs ; do
    for s_sync in $sites_sync_dir ; do echo $s_sync ; done | grep -q $s
    if [ $? -ne 0 ] ; then
       echo DEBUG $s REMOVED from gitlab or sitedb
       for s_u in $list_sites_updated ; do echo $s_u ; done | grep -q $s
       [ $? -eq 0 ] || list_sites_updated="$list_sites_updated $s"
    fi
done


export UPDATED_SITES="$(echo $list_sites_updated)"
publish_needed=0

[ -L ${SYNC_DIR}/SITECONF/local ] || { publish_needed=1 ; ln  -s '$(CMS_LOCAL_SITE)' ${SYNC_DIR}/SITECONF/local ; }
/bin/rm ${ERR_FILE} 1>/dev/null 2>&1

if [ "x$UPDATED_SITES" == "x" ] ; then
   echo INFO nothing to do. UPDATED_SITES is empty
else
   echo INFO publication needed
   publish_needed=1
fi

if [ $publish_needed -eq 0 ] ; then
   echo INFO publish not needed
   # release thelock:
   # -----------------------
   echo "Releasing lock for cvmfs/stcnf_updt"
   /bin/rm ${EXC_LOCK}
   EXC_LOCK=""
   exit 0
fi

# Publish needed
cvmfs_server transaction
status=$?
cvmfs_server_transaction_check $status $what
if [ $? -eq 0 ] ; then
   echo INFO transaction OK for $what
else
   printf "$0 cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom
   cd
   exit 1
fi

# Check if ${SYNC_DIR}/SITECONF is sane
check_rsync_source_siteconf_sanity ${SYNC_DIR}/SITECONF
if [ $? -eq 0 ] ; then
   echo INFO ${SYNC_DIR}/SITECONF is sane
else
   printf "ERROR $0 ${SYNC_DIR}/SITECONF is insane\n$(ls -al ${SYNC_DIR}/SITECONF)\n" | mail -s "ERROR: ${SYNC_DIR}/SITECONF insane" $notifytowhom
   ( cd ; cvmfs_server abort -f ; ) ;
   /bin/rm ${EXC_LOCK}
   exit 1
fi

( cd /cvmfs/cms.cern.ch ; tar czf $HOME/SITECONF.tar.gz.copy $(echo $(for d in SITECONF/* ; do echo $d ; done | grep ^SITECONF/T[0-9]_)) && { /bin/cp $HOME/SITECONF.tar.gz $HOME/SITECONF.tar.gz.1 ; /bin/cp $HOME/SITECONF.tar.gz.copy $HOME/SITECONF.tar.gz ; } ; ) ;

echo $RSYNC_SITES | grep -q /SITECONF
if [ $? -ne 0 ] ; then
   printf "ERROR $0 $RSYNC_SITES does not have /SITECONF\n$(ls -al $RSYNC_SITES)\n" | mail -s "ERROR: $RSYNC_SITES insane" $notifytowhom
   ( cd ; cvmfs_server abort -f ; ) ;
   /bin/rm ${EXC_LOCK}
   exit 1
fi 
echo rsync -arzuvp --exclude=.cvmfscatalog --delete ${SYNC_DIR}/SITECONF/ $RSYNC_SITES
thelog=$HOME/logs/cvmfs_check_and_update_siteconf_rsync.log 
rsync -arzuvp --exclude=.cvmfscatalog --delete ${SYNC_DIR}/SITECONF/ $RSYNC_SITES > $thelog 2>&1 # option --delete deletes extraneous files from dest dirs
if [ $? -eq 0 ] ; then
      publish_needed=0
      i=0
      for f in $(grep ^T[0-9] $thelog | grep -v .git/ 2>/dev/null) ; do
         i=$(expr $i + 1)
         #[ -f "$RSYNC_SITES/$f" ] || { echo "[ $i ] " $RSYNC_SITES/$f is not a file $publish_needed ; continue ; } ;
         [ -f "$RSYNC_SITES/$f" ] || { continue ; } ;
         publish_needed=1
         echo "[ $i ] " $RSYNC_SITES/$f is a file $publish_needed
      done
      grep -q "deleting T[0-9]_" $thelog
      [ $? -eq 0 ] && publish_needed=1
      echo INFO check point publish_needed $publish_needed
      if [ $publish_needed -eq 0 ] ; then
         echo INFO publish was not needed, So ending the transaction
         printf "$what publish was not needed, though there are $UPDATED_SITES\nCheck $HOME/logs/cvmfs_check_and_update_siteconf_rsync.log\n$(cat $HOME/logs/cvmfs_check_and_update_siteconf_rsync.log | sed 's#%#%%#g')\nCheck $HOME/logs/cvmfs_check_and_update_siteconf.log\n$(cat $HOME/logs/cvmfs_check_and_update_siteconf.log | sed 's#%#%%#g')\n" | mail -s "ERROR $what publish was not needed but with updated sites" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ;
         /bin/rm ${EXC_LOCK}
         exit 1
      else
         if [ -L /cvmfs/cms.cern.ch/SITECONF/local ] ; then
            printf "$what /cvmfs/cms.cern.ch/SITECONF/local exists\n$(ls -al /cvmfs/cms.cern.ch/SITECONF/local | sed 's#%#%%#g')\n" | mail -s "INFO /cvmfs/cms.cern.ch/SITECONF/local" $notifytowhom
         else
            ln -s '$(CMS_LOCAL_SITE)' /cvmfs/cms.cern.ch/SITECONF/local
            if [ $? -eq 0 ] ; then
               printf "$what local symlink went OK\nln -s '$\(CMS_LOCAL_SITE\)' /cvmfs/cms.cern.ch/SITECONF/local\n" | mail -s "INFO $what" $notifytowhom
               publish_needed=1
            else
               printf "$what local symlink went failed\nln -s '$\(CMS_LOCAL_SITE\)' /cvmfs/cms.cern.ch/SITECONF/local\n" | mail -s "ERROR $what local symlink" $notifytowhom
               ( cd ; cvmfs_server abort -f ; ) ;
               /bin/rm ${EXC_LOCK}
               exit 1
            fi
         fi
         echo INFO publish necessary
         YMDM=$(date -u +%Y%m%d%H)
         grep "$YMDM " $updated_list | grep -q "$UPDATED_SITES"
         if [ $? -ne 0 ] ; then
            echo $YMDM $(/bin/date +%s) $(/bin/date -u) "$UPDATED_SITES" to $updated_list
            [ $(/bin/hostname -f) == $cvmfs_server_name ] && echo $YMDM $(/bin/date +%s) $(/bin/date -u) "$UPDATED_SITES" >> $updated_list
         fi

         echo INFO publishing $RSYNC_SITES
         currdir=$(pwd)
         cd
         time cvmfs_server publish > $HOME/logs/cvmfs_server+publish.log 2>&1
         status=$?
         cd $currdir
         if [ $status -eq 0 ] ; then
            echo "$what cvmfs_server_publish OK"
         else
            echo ERROR failed cvmfs_server publish
            printf "$what cvmfs_server_publish failed UPDATED_SITES=$UPDATED_SITES\nCheck $HOME/logs/cvmfs_check_and_update_siteconf_rsync.log\n$(cat $HOME/logs/cvmfs_check_and_update_siteconf_rsync.log | sed 's#%#%%#g')\nCheck $HOME/logs/cvmfs_check_and_update_siteconf.log\n$(cat $HOME/logs/cvmfs_check_and_update_siteconf.log | sed 's#%#%%#g')\n" | mail -s "ERROR $what cvmfs_server_publish failed" $notifytowhom
            ( cd ; cvmfs_server abort -f ; ) ;
            /bin/rm ${EXC_LOCK}
            exit 1
         fi
         printf "$what publish is needed UPDATED_SITES=$UPDATED_SITES\nCheck $HOME/logs/cvmfs_check_and_update_siteconf_rsync.log\n$(cat $HOME/logs/cvmfs_check_and_update_siteconf_rsync.log | sed 's#%#%%#g')\nCheck $HOME/logs/cvmfs_check_and_update_siteconf.log\n$(cat $HOME/logs/cvmfs_check_and_update_siteconf.log | sed 's#%#%%#g')\n" | mail -s "DEBUG $what publish is necessary" $notifytowhom
      fi
else
      echo ERROR failed : rsync -arzuvp $SYNC_DIR $(dirname $RSYNC_SITES)
      printf "$what FAILED: rsync -arzuvp $SYNC_DIR $(dirname $RSYNC_SITES)\n" | mail -s "$what ERROR FAILED rsync" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ;
      /bin/rm ${EXC_LOCK}
      exit 1
fi

# #############################################################################



# release thelock:
# -----------------------
echo "Releasing lock for cvmfs/stcnf_updt"
/bin/rm ${EXC_LOCK}
EXC_LOCK=""
# #############################################################################

exit 0
