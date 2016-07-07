#!/bin/sh
if [ $# -lt 3 ] ; then
   echo ERROR $(basename $0) CMSSW_RELEASE SCRAM_ARCH buildhash
   exit 1
fi
notifytowhom=bockjoo@phys.ufl.edu
updated_list=/cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates
export bootstrap_script=http://cmsrep.cern.ch/cmssw/cms/bootstrap.sh
export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
export SCRAM_ARCH=$2 # fc22_ppc64le_gcc530
export CMSSW_RELEASE=$1 # CMSSW_8_0_0_pre6
export BUILD_HASH=$3
echo INFO CMSSW_RELEASE=$CMSSW_RELEASE SCRAM_ARCH=$SCRAM_ARCH BUILD_HASH=$BUILD_HASH

printf "$(basename $0): Starting to try to post-install $CMSSW_RELEASE ${SCRAM_ARCH}\n\n" | mail -s "$(basename $0) Starting post-install " $notifytowhom

#[ -d $HOME/POWER8 ] || mkdir $HOME/POWER8
#cd $HOME/POWER8

#echo VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
#grep -q "$CMSSW_RELEASE $SCRAM_ARCH " $updated_list
#if [ $? -eq 0 ] ; then
#   echo INFO "$CMSSW_RELEASE $SCRAM_ARCH" found in $updated_list
#   exit 0
#fi

#files="proot qemu-ppc64le fedora-22-ppc64le-rootfs.tar.bz2"
#for f in $files ; do
#  [ -f $f ] && continue
#  if [ "x$f" == "xfedora-22-ppc64le-rootfs.tar.bz2" ] ; then
#     [ -d fedora-22-ppc64le-rootfs ] && continue
#  fi
#  wget -q -O $f http://davidlt.web.cern.ch/davidlt/vault/proot/$f
#  echo Download status=$? for $f
#  [ "x$f" == "xproot" ] && chmod a+x proot
#  [ "x$f" == "xqemu-ppc64le" ] && chmod a+x qemu-ppc64le
#  if [ "x$f" == "xfedora-22-ppc64le-rootfs.tar.bz2" ] ; then
#     bzip2 -d fedora-22-ppc64le-rootfs.tar.bz2 
#     tar xvf fedora-22-ppc64le-rootfs.tar
#  fi
#done

#echo INFO $(basename $0) going to cvmfs write mode cvmfs_server transaction
#cvmfs_server transaction
if [ $? -ne 0 ] ; then
   printf "$(basename $0): cvfms_server transaction failed to install $CMSSW_RELEASE ${SCRAM_ARCH}\n$(cat $HOME/cvmfs_install_POWER8.log | sed 's###g')\n" | mail -s "ERROR installation of $CMSSW_RELEASE ${SCRAM_ARCH} failed " $notifytowhom
   exit 1
fi

export RPM_INSTALL_PREFIX=$VO_CMS_SW_DIR
if [ "X$CMS_INSTALL_PREFIX" = "X" ] ; then
   CMS_INSTALL_PREFIX=$RPM_INSTALL_PREFIX
   export CMS_INSTALL_PREFIX
fi

echo INFO doing it 1
perl -p -i -e "s|\Q/data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build/tmp/BUILDROOT/${BUILD_HASH}/opt/cmssw\E|/data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build|g;s|\Q/data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build\E|$CMS_INSTALL_PREFIX|g" $RPM_INSTALL_PREFIX/${SCRAM_ARCH}/cms/cmssw/${CMSSW_RELEASE}/etc/profile.d/init.sh
status=$?

echo INFO status=$status doing it 2
perl -p -i -e "s|\Q/data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build/tmp/BUILDROOT/${BUILD_HASH}/opt/cmssw\E|/data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build|g;s|\Q/data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build\E|$CMS_INSTALL_PREFIX|g" $RPM_INSTALL_PREFIX/${SCRAM_ARCH}/cms/cmssw/${CMSSW_RELEASE}/etc/profile.d/init.csh
status=$(expr $status + $?)
#export SCRAM_ARCH=${SCRAM_ARCH}

cd $RPM_INSTALL_PREFIX/${SCRAM_ARCH}/cms/cmssw/${CMSSW_RELEASE}
if [ -e src.tar.gz ] ; then
  tar xzf src.tar.gz
  rm -fR  src.tar.gz
fi

scramver=`cat config/scram_version`
status=$(expr $status + $?)
SCRAMV1_ROOT=$RPM_INSTALL_PREFIX/${SCRAM_ARCH}/lcg/SCRAMV1/$scramver

if [ -d python ]; then
  echo INFO doing it 3
  perl -p -i -e "s|\Q/data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build/tmp/BUILDROOT/${BUILD_HASH}/opt/cmssw\E|/data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build|g;s|\Q/data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build\E|$CMS_INSTALL_PREFIX|g" $(find python -maxdepth 1 -type f)
  status=$(expr $status + $?)
fi

echo INFO doing it 4

(SCRAM_TOOL_HOME=$SCRAMV1_ROOT/src; export SCRAM_TOOL_HOME; ./config/SCRAM/projectAreaRename.pl /data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build/tmp/BUILDROOT/${BUILD_HASH}/opt/cmssw $CMS_INSTALL_PREFIX  ${SCRAM_ARCH} ; exit $? ; )
status=$(expr $status + $?)

echo INFO doing it 5

(SCRAM_TOOL_HOME=$SCRAMV1_ROOT/src; export SCRAM_TOOL_HOME; ./config/SCRAM/projectAreaRename.pl /data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build  $CMS_INSTALL_PREFIX  ${SCRAM_ARCH} ; exit $? ; )
status=$(expr $status + $?)

:

echo INFO doing it 6

for lib in biglib/${SCRAM_ARCH} lib/${SCRAM_ARCH} ; do
  if [ -f $lib/.edmplugincache ] ; then
    find  $lib -name "*.edmplugin" -type f -exec touch {} \;
    touch $lib/.edmplugincache
  fi
done

echo INFO doing it 7

[ -f $RPM_INSTALL_PREFIX/etc/scramrc/cmssw.map ] || ( mkdir -p $RPM_INSTALL_PREFIX/etc/scramrc && echo 'CMSSW=$SCRAM_ARCH/cms/cmssw/CMSSW_*' > $RPM_INSTALL_PREFIX/etc/scramrc/cmssw.map ; exit $? ; )
status=$(expr $status + $?)

echo INFO doing it 8

case ${SCRAM_ARCH} in
  slc6_amd64_*)
    FILE_PKG=$(echo "external/gcc/5.3.0 external/python/2.7.11 lcg/SCRAMV1/V2_2_6_pre5 cms/cms-git-tools/151104.0 cms/cmssw-tool-conf/33.0-ikhhed" | tr ' ' '\n' | grep 'external/file/')
    FILE_PATH=$RPM_INSTALL_PREFIX/${SCRAM_ARCH}/$FILE_PKG
    PATCHELF_PKG=$(echo "external/gcc/5.3.0 external/python/2.7.11 lcg/SCRAMV1/V2_2_6_pre5 cms/cms-git-tools/151104.0 cms/cmssw-tool-conf/33.0-ikhhed" | tr ' ' '\n' | grep 'external/patchelf/')
    PATCHELF_PATH=$RPM_INSTALL_PREFIX/${SCRAM_ARCH}/$PATCHELF_PKG
    CMSSW_BIN_PATH="$RPM_INSTALL_PREFIX/${SCRAM_ARCH}/cms/cmssw/${CMSSW_RELEASE}/bin/${SCRAM_ARCH} $RPM_INSTALL_PREFIX/${SCRAM_ARCH}/cms/cmssw/${CMSSW_RELEASE}/test/${SCRAM_ARCH}"
    CMSSW_ELF_BIN=$(find $CMSSW_BIN_PATH -type f -exec $FILE_PATH/bin/file {} \; | grep ELF | cut -d':' -f1)
    GLIBC_PKG=$(echo "external/gcc/5.3.0 external/python/2.7.11 lcg/SCRAMV1/V2_2_6_pre5 cms/cms-git-tools/151104.0 cms/cmssw-tool-conf/33.0-ikhhed" | tr ' ' '\n' | grep 'external/glibc/')
    GLIBC_PATH=$CMS_INSTALL_PREFIX/${SCRAM_ARCH}/$GLIBC_PKG
    echo "$CMSSW_ELF_BIN" | xargs -t -n 1 -I% -P $(getconf _NPROCESSORS_ONLN) sh -c "strings % 2>&1 | grep '${SCRAM_ARCH}/external/glibc' 2>&1 >/dev/null && $PATCHELF_PATH/bin/patchelf --set-interpreter $GLIBC_PATH/lib64/ld.so % || true"
esac

echo INFO doing it 9

perl -p -i -e "s|\Q/data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build/tmp/BUILDROOT/${BUILD_HASH}/opt/cmssw\E|/data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build|g;s|\Q/data1/cmsbuild/auto-builds/${CMSSW_RELEASE}-${SCRAM_ARCH}/build/${CMSSW_RELEASE}-build\E|$CMS_INSTALL_PREFIX|g" $RPM_INSTALL_PREFIX/${SCRAM_ARCH}/cms/cmssw/${CMSSW_RELEASE}/.glimpse_full/.glimpse_filenames
status=$(expr $status + $?)
#
cd

#echo INFO executing cvmfs_server publish
#cvmfs_server publish
#status=$(expr $status + $?)
echo script Done status=$status
exit $status

if [ $(ls -al $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null ; echo $? ; ) -eq 0 ] ; then
     echo INFO arch ${SCRAM_ARCH} seems to be already bootstrapped
else
     echo INFO downloading bootstrap.sh for ${SCRAM_ARCH}
     wget -q -O $VO_CMS_SW_DIR/$(basename $bootstrap_script) $bootstrap_script
     #sh -x $VO_CMS_SW_DIR/bootstrap.sh -repository cms setup -path $VO_CMS_SW_DIR -a ${SCRAM_ARCH} > $HOME/bootstrap_${SCRAM_ARCH}.log 2>&1
     #cat $HOME/bootstrap_${SCRAM_ARCH}.log
fi

echo INFO installing $CMSSW_RELEASE ${SCRAM_ARCH} in the proot env
./proot -R $PWD/fedora-22-ppc64le-rootfs -b /cvmfs:/cvmfs -q "$PWD/qemu-ppc64le -cpu POWER8" /bin/sh -c "\
echo INFO bootstrapping ${SCRAM_ARCH} ; \
sh -x $VO_CMS_SW_DIR/bootstrap.sh -repository cms setup -path $VO_CMS_SW_DIR -a ${SCRAM_ARCH} 2>&1 | tee $HOME/bootstrap_${SCRAM_ARCH}.log ; \
star='*' ; \
init_sh=\`ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh -t | head -1\` ; \
if [ -f \$init_sh ] ; then \
   echo INFO sourcing \$init.sh ; \
   source \$init_sh ; \
fi ; \
grep -q mutex_set_max $VO_CMS_SW_DIR/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG 2>/dev/null ; \
if [ \$? -eq 0 ] ; then \
   echo INFO mutex_set_max 100000 already there ; \
else \
   echo INFO adding mutex_set_max 100000 to $VO_CMS_SW_DIR/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG ; \
   echo mutex_set_max 100000 >> $VO_CMS_SW_DIR/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG ; \
fi ; \
echo INFO executing apt-get --assume-yes update ; \
apt-get --assume-yes update ; \
[ \$? -eq 0 ] || { echo apt-get --assume-yes update failed ; exit 1 ; } ; \
second_plus= ; \
echo $CMSSW_RELEASE | grep -q patch && second_plus=-patch ; \
echo INFO executing apt-get --assume-yes install cms+cmssw\${second_plus}+$CMSSW_RELEASE ; \
apt-get --assume-yes install cms+cmssw\${second_plus}+$CMSSW_RELEASE > $HOME/apt_get_install.log 2>&1 ; \
[ \$? -eq 0 ] || { echo apt-get --assume-yes update failed ; cat $HOME/apt_get_install.log ; exit 1 ; } ; \
cat $HOME/apt_get_install.log ; \
"
status=$?
grep Killed $HOME/apt_get_install.log | grep -q projectAreaRename
if [ $? -eq 0 ] ; then
   status=1
fi
echo INFO proot install status=$status
second_plus=
echo $CMSSW_RELEASE | grep -q patch && second_plus=-patch
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
         grep -q "$CMSSW_RELEASE ${SCRAM_ARCH} " $updated_list
         if [ $? -eq 0 ] ; then
            echo INFO "$cmssw $aarch " found in $updated_list
         else
            echo $CMSSW_RELEASE ${SCRAM_ARCH} $(/bin/date +%s) $(/bin/date -u) >> $updated_list
            printf "$(basename $0): $CMSSW_RELEASE ${SCRAM_ARCH} installed " | mail -s "Installed $CMSSW_RELEASE ${SCRAM_ARCH} " $notifytowhom
         fi
      fi
   else
      printf "$(basename $0): $CMSSW_RELEASE ${SCRAM_ARCH} install failed\nNot found:  $VO_CMS_SW_DIR/${SCRAM_ARCH}/cms/cmssw${second_plus}/$CMSSW_RELEASE\n$(cat $HOME/cvmfs_install_POWER8.log | sed 's###g')\n" | mail -s "ERROR installation of $CMSSW_RELEASE ${SCRAM_ARCH} failed " $notifytowhom
   fi
else
   printf "$(basename $0): $CMSSW_RELEASE ${SCRAM_ARCH} install failed\napt-get failed \n$(cat $HOME/cvmfs_install_POWER8.log | sed 's###g')\n" | mail -s "ERROR installation of $CMSSW_RELEASE ${SCRAM_ARCH} failed " $notifytowhom
fi
echo INFO executing cvmfs_server publish
cvmfs_server publish

exit 0

#chmod a+x proot
#chmod a+x qemu-ppc64le
#bzip2 -d fedora-22-ppc64le-rootfs.tar.bz2 
#tar xvf fedora-22-ppc64le-rootfs.tar 

cvmfs_server transaction
if [ $? -eq 0 ] ; then
  #bootstrap_script=http://cmsrep.cern.ch/cmssw/cms/bootstrap.sh
  #VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
  #SCRAM_ARCH=fc22_ppc64le_gcc530
  ./proot -R $PWD/fedora-22-ppc64le-rootfs -b /cvmfs:/cvmfs -q "$PWD/qemu-ppc64le -cpu POWER8"
  cd
  cd POWER8
  #bootstrap_script=http://cmsrep.cern.ch/cmssw/cms/bootstrap.sh
  #VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
  #SCRAM_ARCH=fc22_ppc64le_gcc530
  #wget -q -O $(basename $bootstrap_script) $bootstrap_script
  #cvmfs_server transaction

  #VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
  #SCRAM_ARCH=fc22_ppc64le_gcc530
  if [ $(ls -al $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null ; echo $? ; ) -eq 0 ] ; then
     echo INFO arch ${SCRAM_ARCH} seems to be already bootstrapped
  else
     echo INFO downloading bootstrap.sh for ${SCRAM_ARCH}
     #wget -q -O $VO_CMS_SW_DIR/$(basename $bootstrap_script) $bootstrap_script
     sh -x $VO_CMS_SW_DIR/bootstrap.sh -repository cms setup -path $VO_CMS_SW_DIR -a ${SCRAM_ARCH} > $HOME/bootstrap_${SCRAM_ARCH}.log 2>&1
     cat $HOME/bootstrap_${SCRAM_ARCH}.log
  fi
  exit

##################################################################################################
# This does not look working
##################################################################################################
  # Use SLC6 apt-get
  which_slc=slc6
  uname -a  | grep ^Linux | grep GNU/Linux | grep -q .el5
  [ $? -eq 0 ] && which_slc=slc5
  uname -a  | grep ^Linux | grep GNU/Linux | grep -q .el6
  [ $? -eq 0 ] && which_slc=slc6
  uname -a  | grep ^Linux | grep GNU/Linux | grep -q .el7
  [ $? -eq 0 ] && which_slc=slc7
  second_plus=
  cmssw_release_last_string=$(echo $CMSSW_RELEASE | sed "s#_# #g" | awk '{print $NF}')

  echo "$cmssw_release_last_string" | grep -q patch && second_plus=-patch

  #cd $VO_CMS_SW_DIR
  SLC_SCRAM_ARCH_DEFAULT=$(/bin/ls -alt /cvmfs/cms.cern.ch | awk '{print $NF}' | grep ^${which_slc}_amd64 | head -1)
  if [ -f "$(ls -t $VO_CMS_SW_DIR/${SLC_SCRAM_ARCH_DEFAULT}/external/apt/*/etc/profile.d/init.sh | head -1)" ] ; then
      if [ ! -f "$(ls -t $VO_CMS_SW_DIR/${SLC_SCRAM_ARCH_DEFAULT}/external/curl/*/etc/profile.d/init.sh | head -1)" ] ; then
         echo Warning using the alternative $(/bin/ls -alt /cvmfs/cms.cern.ch | awk '{print $NF}' | grep ^${which_slc}_amd64 | head -2 | tail -1) instead of $SLC_SCRAM_ARCH_DEFAULT
         SLC_SCRAM_ARCH_DEFAULT=$(/bin/ls -alt /cvmfs/cms.cern.ch | awk '{print $NF}' | grep ^${which_slc}_amd64 | head -2 | tail -1)
      fi
  fi
  SLC_SCRAM_ARCH=$SLC_SCRAM_ARCH_DEFAULT
  echo DEBUG we will use SLC_SCRAM_ARCH=$SLC_SCRAM_ARCH for the non-native arch ${SCRAM_ARCH}
  echo DEBUG SLC_SCRAM_ARCH_DEFAULT=$SLC_SCRAM_ARCH_DEFAULT
  apt_config=$(ls -t $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/apt.conf | head -1)
  cp ${apt_config} $HOME/apt.conf
  SLC_SCRAM_ARCH_METHODS=$(for d in /cvmfs/cms.cern.ch/${SLC_SCRAM_ARCH}/external/apt/*/lib/apt/methods/   ; do echo $d ; done | head -1)
  OSX_SCRAM_ARCH_METHODS=$(grep methods $HOME/apt.conf | cut -d\" -f2 | grep ${SCRAM_ARCH})
  echo DEBUG SLC_SCRAM_ARCH_METHODS=$SLC_SCRAM_ARCH_METHODS
  echo DEBUG OSX_SCRAM_ARCH_METHODS=$OSX_SCRAM_ARCH_METHODS
  sed -i "s#${OSX_SCRAM_ARCH_METHODS}#${SLC_SCRAM_ARCH_METHODS}#g" $HOME/apt.conf
  apt_config=$HOME/apt.conf 
  # Now setup SLC apt-get
  if [ -f "$(ls -t $VO_CMS_SW_DIR/${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)" ] ; then
      echo DEBUG using $(ls -t $VO_CMS_SW_DIR/${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)
      source $(ls -t $VO_CMS_SW_DIR/${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh | head -1)
  else
      echo ERROR failed apt init.sh does not exist: $VO_CMS_SW_DIR/${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh
      #printf "install_cmssw_non_native() apt init.sh does not exist: $VO_CMS_SW_DIR/${SLC_SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh\n" | mail -s "$(basename $0) failed" $notifytowhom
      #return 1
  fi

  if [ -f "$(ls -t $VO_CMS_SW_DIR/${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)" ] ; then
      # for cvmfs_server
      source $(ls -t $VO_CMS_SW_DIR/${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh | head -1)
      ldd $(which curl)
      #echo INFO ldd $(which curl) status=$?
      ldd $(which curl) 2>&1 | grep OPENSSL | grep -q "not found"
      if [ $? -eq 0 ] ; then
         source $(ls -t $VO_CMS_SW_DIR/${SLC_SCRAM_ARCH}/external/openssl/*/etc/profile.d/init.sh | head -1)
      fi
      
      ldd $(which curl) 2>&1 | grep -q "not found"
      if [ $? -eq 0 ] ; then
         echo ERROR failed to set up curl env\nSome library may be missing $(ldd $(which curl))
         #printf "install_cmssw()  set up curl env failed\nSome library may be missing\necho ldd $(which curl) result follows\n$(ldd $(which curl))\n" | mail -s "ERROR install_cmssw() set up curl env failed" $notifytowhom
         #return 1
      fi
  else
      echo Warning curl init.sh does not exist: $VO_CMS_SW_DIR/${SLC_SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh
      ldd $(which curl)
      echo INFO ldd $(which curl) status=$?
      #printf "install_cmssw() curl init.sh does not exist: ${SCRAM_ARCH}/external/curl/*/etc/profile.d/init.sh\n" | mail -s "$(basename $0) failed" $notifytowhom
      #return 1
  fi
  export RPM_CONFIGDIR=$(for d in $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/rpm/*/lib/rpm ; do echo $d ; done | head -1)
  cvmfs_server transaction
  apt-get --assume-yes -c=$apt_config update 2>&1 | tee $HOME/apt_get_update.log 

  rpm -qa --dbpath /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm | grep fakesystem
  if [ $(rpm -qa --dbpath /cvmfs/cms.cern.ch/${SCRAM_ARCH}/var/lib/rpm | grep -q fakesystem ; echo $? ) -ne 0 ] ; then
      fakesystems=$(apt-cache -c=$apt_config pkgnames | grep fakesystem)
      echo INFO installing fakes $fakesystems
      #printf "install_cmssw_non_native() installing fakesystems\n" | mail -s "install_cmssw_non_native() installing fakesystems" $notifytowhom
     apt-get --assume-yes -c=$apt_config install $fakesystems >& $HOME/apt_get_install_fakesystems.log &
  fi

  apt-get --assume-yes -c=$apt_config install cms+cmssw${second_plus}+$CMSSW_RELEASE 2>&1 | tee $HOME/apt_get_install.log


##################################################################################################

if [ ] ; then
  if [ -f "$(ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh -t | head -1)" ] ; then
    source $(ls $VO_CMS_SW_DIR/${SCRAM_ARCH}/external/apt/*/etc/profile.d/init.sh -t | head -1)
  fi
  grep -q mutex_set_max $VO_CMS_SW_DIR/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
  [ $? -eq 0 ] || echo mutex_set_max 100000 >> $VO_CMS_SW_DIR/${SCRAM_ARCH}/var/lib/rpm/DB_CONFIG
  echo INFO executing apt-get --assume-yes update
  apt-get --assume-yes update
  second_plus=
  echo $CMSSW_RELEASE | grep -q patch && second_plus=-patch
  echo INFO executing apt-get --assume-yes install cms+cmssw${second_plus}+$CMSSW_RELEASE
  nohup apt-get --assume-yes install cms+cmssw${second_plus}+$CMSSW_RELEASE > $HOME/apt_get_install.log 2>&1
  status=$?
  cat $HOME/apt_get_install.log
  echo INFO apt-get --assume-yes install cms+cmssw${second_plus}+$CMSSW_RELEASE status=$status
  echo INFO exiting out of proot

  exit
fi # if [ ] ; then
  echo INFO adding $aarch to /cvmfs/cms.cern.ch/.cvmfsdirtab
  add_nested_entry_to_cvmfsdirtab ${SCRAM_ARCH}
  ls -al $VO_CMS_SW_DIR/${SCRAM_ARCH}/.cvmfscatalog 2>/dev/null 1>/dev/null
  if [ $? -eq 0 ] ; then
     echo INFO $VO_CMS_SW_DIR/${SCRAM_ARCH}/.cvmfscatalog exists
  else
     echo INFO creating $VO_CMS_SW_DIR/${SCRAM_ARCH}/.cvmfscatalog
     touch $VO_CMS_SW_DIR/${SCRAM_ARCH}/.cvmfscatalog
     grep -q "$CMSSW_RELEASE ${SCRAM_ARCH} " $updated_list
     if [ $? -eq 0 ] ; then
        echo INFO "$cmssw $aarch " found in $updated_list
     else
        echo $CMSSW_RELEASE ${SCRAM_ARCH} $(/bin/date +%s) $(/bin/date -u) >> $updated_list
        printf "$(basename $0): $CMSSW_RELEASE ${SCRAM_ARCH} installed " | mail -s "Installed $CMSSW_RELEASE ${SCRAM_ARCH} " $notifytowhom
     fi
  fi
  cvmfs_server publish
else
  echo ERROR cvmfs_server transaction failed
fi

cd -

exit 0
