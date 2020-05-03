#!/bin/sh
host=melrose.ihepa.ufl.edu
port=8080
host=cms.rc.ufl.edu
port=8443
MINUTE=$(date +%M)
weborigin=http://${host}:${port}/cmssoft/cvmfs
workdir=$HOME
if [ $# -gt 0 ] ; then
   workdir=$1
fi
i=0
deleted_files="
cron_install_cmssw_functions
cvmfs_check_siteconf_git.sh 
create_host_proxy_download_siteconf.sh
cmssoft_rsync_publish_slc6.sh
cmssoft_rsync_slc6.sh
cic_send_log.sh
cic_send_log.py
create_lhapdf_checksum.sh
create_lhapdf_softlink.sh
cvmfs_install_POWER8_apt.sh
cvmfs_install_aarch64_apt.sh
"

files="cron_install_cmssw.sh cron_download_lhapdf.sh cron_install_cmssw_functions cvmfs_check_siteconf_git.sh update_cmssw_git_mirror.sh create_host_proxy_download_siteconf.sh install_crab3.sh cmssoft_rsync_publish_slc6.sh cmssoft_rsync_slc6.sh cic_send_log.sh cic_send_log.py cron_rsync_generator_package_from_eos.sh create_lhapdf_checksum.sh create_lhapdf_softlink.sh lhapdf_list.txt list_requested_arch_cmssws_cvmfs.txt cvmfs_update_pilot_config.sh install_comp_python.sh cvmfs_install_POWER8.sh cvmfs_install_POWER8_apt.sh cvmfs_postinstall_POWER8.sh cvmfs_install_aarch64.sh cvmfs_install_aarch64_apt.sh cvmfs_check_and_update_siteconf.sh"
files="cron_install_cmssw.sh cron_download_lhapdf.sh update_cmssw_git_mirror.sh install_crab3.sh install_phedexagents.sh cron_rsync_generator_package_from_eos.sh lhapdf_list.txt list_requested_arch_cmssws_cvmfs.txt cvmfs_update_pilot_config.sh install_comp_python.sh cvmfs_install_POWER8.sh cvmfs_postinstall_POWER8.sh cvmfs_install_aarch64.sh cvmfs_check_and_update_siteconf.sh install_spacemonclient.sh cvmfscatalogsize cvmfscatalogsize_check.sh install_cmssw_centos72_exotic_archs.sh install_xrootd_client.sh install_comp_python_cmspkg.sh update_ca_crl.sh cron_rsync_generator_package_from_eos_individual.sh cvmfs_update_cmssw_git_mirror.sh cvmfs_update_cmssw_git_mirror_v3.sh install_rucio_client.sh install_slc6_amd64_gcc493_crab3.sh run_install_cmssw.sh"

for f in $files ; do
  i=$(expr $i + 1)
  if [ -f $workdir/$f ] ; then
     [ -f $workdir/${f}.oo ] || cp -pR  $workdir/$f $workdir/${f}.oo
  fi
  echo "[ $i ]" INFO dowloading $f to $workdir/$f
  wget -q -O /dev/null $weborigin/$f
  if [ $? -ne 0 ] ; then
     echo ERROR failed to test-download $f : wget -q -O /dev/null $weborigin/$f
     exit 1
  fi
  wget -q -O $workdir/$f $weborigin/$f
  echo "[ $i ]" Status: $?
  echo "[ $i ]" Date Now: $(date)
  echo $f | grep sh$
  [ $? -eq 0 ] && chmod a+x $workdir/$f
  [ "x$f" == "xcvmfscatalogsize" ] && chmod a+x $workdir/$f
  ls -al $workdir/$f
done

files="functions-cms-cvmfs-mgmt lhapdf_list.txt list_requested_arch_cmssws_cvmfs.txt cron_install_cmssw.config"
i=0
for f in $files ; do
   i=$(expr $i + 1)
   echo "[ $i ]" INFO dowloading $f to $workdir/$f
   wget -q -O $workdir/$f $weborigin/$f
   echo "[ $i ]" $f: Download Status: $?
   echo "[ $i ]" Date Now: $(date)
   ls -al $workdir/$f
done

files="README.gridpacks README.siteconf README.CVMFS.Variant.Symlink"
i=0
for f in $files ; do
   i=$(expr $i + 1)
   echo "[ $i ]" INFO dowloading $f to $workdir/$f
   wget -q -O $workdir/$f $weborigin/$f
   echo "[ $i ]" $f: Download Status: $?
   echo "[ $i ]" Date Now: $(date)
   ls -al $workdir/$f
done

exit 0
