#!/bin/sh
notifytowhom=bockjoo@phys.ufl.edu
updated_list=/cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates
#export bootstrap_script=http://cmsrep.cern.ch/cmssw/cms/bootstrap.sh
export bootstrap_script=http://cmsrep.cern.ch/cmssw/repos/bootstrap.sh
export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
export SCRAM_ARCH=fc22_ppc64le_gcc530
export CMSSW_RELEASE=CMSSW_8_0_0_pre6
export SCRAM_ARCH=slc7_aarch64_gcc530
export CMSSW_RELEASE=CMSSW_8_0_1
export CMSSW_RELEASE=CMSSW_8_0_2
[ $# -gt 0 ] && export SCRAM_ARCH=$1
[ $# -gt 1 ] && export CMSSW_RELEASE=$2

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

#printf "$(basename $0): Starting to try to install $CMSSW_RELEASE ${SCRAM_ARCH}\n\n" | mail -s "$(basename $0) Starting " $notifytowhom

[ -d $HOME/POWER8 ] || mkdir $HOME/POWER8
cd $HOME/POWER8

echo VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
grep -q "$CMSSW_RELEASE $SCRAM_ARCH " $updated_list
if [ $? -eq 0 ] ; then
   echo INFO "$CMSSW_RELEASE $SCRAM_ARCH" found in $updated_list
   exit 0
fi

files="proot qemu-aarch64 centos-7.2.1511-aarch64-rootfs.tar.bz2 qemu-ppc64le"
for f in $files ; do
  [ -f $f ] && continue
  if [ "x$f" == "xfedora-22-ppc64le-rootfs.tar.bz2" ] ; then
     [ -d fedora-22-ppc64le-rootfs ] && continue
  fi
  if [ "x$f" == "xcentos-7.2.1511-aarch64-rootfs.tar.bz2" ] ; then
     [ -d centos-7.2.1511-aarch64-rootfs ] && continue
  fi
  wget -q -O $f http://davidlt.web.cern.ch/davidlt/vault/proot/$f
  echo Download status=$? for $f
  [ "x$f" == "xproot" ] && chmod a+x proot
  [ "x$f" == "xqemu-ppc64le" ] && chmod a+x qemu-ppc64le
  [ "x$f" == "xqemu-aarch64" ] && chmod a+x qemu-aarch64
  #if [ "x$f" == "xfedora-22-ppc64le-rootfs.tar.bz2" ] ; then
  #   bzip2 -d fedora-22-ppc64le-rootfs.tar.bz2 
  #   tar xvf fedora-22-ppc64le-rootfs.tar
  #fi
  if [ "x$f" == "xcentos-7.2.1511-aarch64-rootfs.tar.bz2" ] ; then
     bzip2 -d centos-7.2.1511-aarch64-rootfs.tar.bz2 
     tar xvf centos-7.2.1511-aarch64-rootfs.tar
  fi
done
echo INFO $(basename $0) going to cvmfs write mode cvmfs_server transaction
cvmfs_server transaction
if [ $? -ne 0 ] ; then
   echo ERROR cvmfs_server transaction failed. Exiting $(basename $0)...
   printf "$(basename $0): cvfms_server transaction failed to install $CMSSW_RELEASE ${SCRAM_ARCH}\n$(cat $HOME/logs/cvmfs_install_aarch64.log | sed 's#%#%%#g')\n" | mail -s "ERROR installation of $CMSSW_RELEASE ${SCRAM_ARCH} failed " $notifytowhom
   exit 1
fi

if [ $(ls -al $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/rpm/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null ; echo $? ; ) -eq 0 ] ; then
     echo INFO arch ${SCRAM_ARCH} seems to be already bootstrapped
else
     echo INFO downloading bootstrap.sh for ${SCRAM_ARCH}
     wget -q -O $VO_CMS_SW_DIR/$(basename $bootstrap_script) $bootstrap_script
     #sh -x $VO_CMS_SW_DIR/bootstrap.sh -repository cms setup -path $VO_CMS_SW_DIR -a ${SCRAM_ARCH} > $HOME/bootstrap_${SCRAM_ARCH}.log 2>&1
     #cat $HOME/bootstrap_${SCRAM_ARCH}.log
fi

echo INFO installing $CMSSW_RELEASE ${SCRAM_ARCH} in the proot env

./proot -R $PWD/centos-7.2.1511-aarch64-rootfs -b /cvmfs:/cvmfs -q "$PWD/qemu-aarch64 -cpu cortex-a57" /bin/sh -c "\
star='*' ; \
init_sh=\`ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/rpm/*/etc/profile.d/init.sh -t | head -1\` ; \
if [ -f \"\$init_sh\" ] ; then \
   echo INFO sourcing \$init.sh ; \
   source \$init_sh ; \
else \
   echo INFO bootstrapping ${SCRAM_ARCH} ; \
   sh -x $VO_CMS_SW_DIR/bootstrap.sh -repository cms setup -path $VO_CMS_SW_DIR -a ${SCRAM_ARCH} ; \
   [ \$? -eq 0 ] || { echo proot_status=1 ; exit 1 ; } ; \
   init_sh=\`ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/rpm/*/etc/profile.d/init.sh -t | head -1\` ; \
   if [ -f \"\$init_sh\" ] ; then \
      echo INFO sourcing \$init.sh ; \
      source \$init_sh ; \
   else \
      echo ERROR init.sh not found for apt ; \
   fi ; \
fi ; \
grep -q mutex_set_max $VO_CMS_SW_DIR/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG 2>/dev/null ; \
if [ \$? -eq 0 ] ; then \
   echo INFO mutex_set_max 100000 already there ; \
else \
   echo INFO adding mutex_set_max 100000 to $VO_CMS_SW_DIR/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG ; \
   echo mutex_set_max 100000 >> $VO_CMS_SW_DIR/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG ; \
fi ; \
which cmspkg 2>/dev/null 1>/dev/null ; \
[ \$? -eq 0 ] || { export PATH=\$PATH:/cvmfs/cms.cern.ch/common ; } ; \
echo INFO executing cmspkg -a ${SCRAM_ARCH} update ; \
cmspkg -a ${SCRAM_ARCH} -y upgrade ; \
[ \$? -eq 0 ] || { echo cmspkg -a ${SCRAM_ARCH} -y upgrade failed ; echo proot_status=1 ; exit 1 ; } ; \
cmspkg -a ${SCRAM_ARCH} update ; \
[ \$? -eq 0 ] || { echo cmspkg -a ${SCRAM_ARCH} update failed ; echo proot_status=1 ; exit 1 ; } ; \
second_plus= ; \
echo $CMSSW_RELEASE | grep -q patch && second_plus=-patch ; \
echo INFO executing cmspkg -a ${SCRAM_ARCH} -y install cms+cmssw\${second_plus}+$CMSSW_RELEASE ; \
cmspkg -a ${SCRAM_ARCH} -y install cms+cmssw\${second_plus}+$CMSSW_RELEASE > $HOME/logs/cmspkg_install.log 2>&1 ; \
[ \$? -eq 0 ] || { echo cmspkg -a ${SCRAM_ARCH} -y install cms+cmssw\${second_plus}+$CMSSW_RELEASE failed ; cat $HOME/logs/cmspkg_install.log ; echo proot_status=1 ; exit 1 ; } ; \
cat $HOME/logs/cmspkg_install.log ; \
echo proot_status=0" > $HOME/logs/proot.aarch64.log 2>&1 &
job_pid=$!

second_plus=
echo $CMSSW_RELEASE | grep -q patch && second_plus=-patch

if [ ] ; then
n=10800 # 180 minues
i=0
nkill=0
while [ $i -lt $n ] ;do
   status=$(grep proot_status= $HOME/logs/proot.aarch64.log | cut -d= -f2)
   if [ "x$status" != "x" ] ; then
      [ $status -eq 0 ] || break
   fi 
   # if we have more than enough memory, don't do this
   [ $(/usr/bin/free -g | grep ^Mem | awk '{print $2}') -gt 14 ] && break
   i=$(expr $i + 1)
   ps auxwww | grep -v grep | grep perl | grep -q projectAreaRename.pl
   if [ $? -eq 0 ] ; then
      [ $(expr $i % 30) -eq 0 ] && { echo DEBUG grep cms+cmssw${second_plus}+${CMSSW_RELEASE} $HOME/POWER8/apt_get_install.${CMSSW_RELEASE}.${SCRAM_ARCH}.log ; grep ^cms+cmssw${second_plus}+${CMSSW_RELEASE} $HOME/POWER8/apt_get_install.${CMSSW_RELEASE}.${SCRAM_ARCH}.log ; } ;
      grep -q ^cms+cmssw${second_plus}+${CMSSW_RELEASE} $HOME/POWER8/apt_get_install.${CMSSW_RELEASE}.${SCRAM_ARCH}.log
      if [ $? -eq 0 ] ; then
         echo KILLING the process
         ps auxwww | grep -v grep | grep perl | grep projectAreaRename.pl
         pid=$(ps auxwww | grep -v grep | grep perl | grep projectAreaRename.pl | awk '{print $2}')
         kill -KILL $pid
         nkill=$(expr $nkill + 1)
         echo INFO nkill=$nkill
      else
         echo Not killing it yet
         ps auxwww | grep -v grep | grep perl | grep projectAreaRename.pl
      fi
   fi
   [ $nkill -eq 2 ] && break
   [ $(expr $i % 30) -eq 0 ] && echo Sleeping 1sec after $i sec out $n sec limit
   sleep 1 # 1m
done
echo INFO doing wait
wait $job_pid
status_job_pid=$?
if [ $nkill -eq 2 ] ; then
   #echo INFO after killing  projectAreaRename.pl executing it from x86_64
   build_hash=$(grep BUILDROOT $HOME/logs/proot.aarch64.log | head -1 | awk '{print $(NF-2)}' | sed 's#/# #g' | awk '{print $(NF-2)}')
   echo INFO after killing  projectAreaRename.pl executing it from x86_64 $HOME/cvmfs_postinstall_POWER8.sh $CMSSW_RELEASE $SCRAM_ARCH $build_hash
   $HOME/cvmfs_postinstall_POWER8.sh $CMSSW_RELEASE $SCRAM_ARCH $build_hash > $HOME/cvmfs_postinstall_POWER8.${CMSSW_RELEASE}.${SCRAM_ARCH}.${build_hash}.log 2>&1
fi
fi # if [ ] ; then
echo INFO doing wait
wait $job_pid
status_job_pid=$?


status=$(grep proot_status= $HOME/logs/proot.aarch64.log | cut -d= -f2) 
echo status=$status status_job_pid=$status_job_pid

echo INFO proot install status=$status

if [ $status -eq 0 ] ; then
   if [ -d $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/cmssw${second_plus}/$CMSSW_RELEASE ] ; then
      echo INFO updating the cvmfs management stuff
      add_nested_entry_to_cvmfsdirtab ${SCRAM_ARCH}
      ls -al $VO_CMS_SW_DIR/${SCRAM_ARCH}/.cvmfscatalog 2>/dev/null 1>/dev/null
      if [ $? -eq 0 ] ; then
         echo INFO $VO_CMS_SW_DIR/${SCRAM_ARCH}/.cvmfscatalog exists
      else
         echo INFO creating $VO_CMS_SW_DIR/${SCRAM_ARCH}/.cvmfscatalog
         touch $VO_CMS_SW_DIR/${SCRAM_ARCH}/.cvmfscatalog
      fi

      grep -q "$CMSSW_RELEASE ${SCRAM_ARCH} " $updated_list
      if [ $? -eq 0 ] ; then
         echo INFO "$CMSSW_RELEASE ${SCRAM_ARCH} " found in $updated_list
      else
         echo INFO adding "$CMSSW_RELEASE ${SCRAM_ARCH} " to $updated_list
         echo $CMSSW_RELEASE ${SCRAM_ARCH} $(/bin/date +%s) $(/bin/date -u) >> $updated_list
         printf "$(basename $0): $CMSSW_RELEASE ${SCRAM_ARCH} installed " | mail -s "Installed $CMSSW_RELEASE ${SCRAM_ARCH} " $notifytowhom
      fi
   else
      echo ERROR $CMSSW_RELEASE ${SCRAM_ARCH} install failed. Not found.
      printf "$(basename $0): $CMSSW_RELEASE ${SCRAM_ARCH} install failed\nNot found:  $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/cmssw${second_plus}/$CMSSW_RELEASE\n$(cat $HOME/cvmfs_install_POWER8.log | sed 's###g')\n" | mail -s "ERROR installation of $CMSSW_RELEASE ${SCRAM_ARCH} failed " $notifytowhom
   fi
else
   echo ERROR $CMSSW_RELEASE ${SCRAM_ARCH} install failed
   printf "$(basename $0): $CMSSW_RELEASE ${SCRAM_ARCH} install failed\n$(cat $HOME/cvmfs_install_POWER8.log | sed 's###g')\n" | mail -s "ERROR installation of $CMSSW_RELEASE ${SCRAM_ARCH} failed " $notifytowhom
fi
echo INFO executing cvmfs_server publish
cvmfs_server publish

exit 0
