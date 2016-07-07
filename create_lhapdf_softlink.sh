#!/bin/sh
#ln -s 6.1a 6.1.5
installed=$1
what=$2

# Check 0
if [ $# -lt 2 ] ; then
   echo ERROR $(basename $0) what+s+installed softlink4what
   exit 1
fi

# Check 1
#wget -q -O- http://oo.ihepa.ufl.edu:8080/cmssoft/lhapdf_list.txt | grep $installed
#if [ $? -ne 0 ] ; then
#   echo ERROR http://oo.ihepa.ufl.edu:8080/cmssoft/lhapdf_list.txt needs to be updated for $installed
#   exit 1
#fi
grep "$installed" $HOME/lhapdf_list.txt
if [ $? -ne 0 ] ; then
   echo ERROR $HOME/lhapdf_list.txt needs to be updated for $installed
   exit 1
fi

# Check 2
lhapdfweb_updates=$(grep ^lhapdfweb_updates= $HOME/cron_download_lhapdf.sh | cut -d= -f2)
for v in $lhapdfweb_updates ; do echo $v ; done | grep $installed
if [ $? -ne 0 ] ; then
   echo ERROR $HOME/cron_download_lhapdf.sh needs to be downloaded for $installed
   exit 1
fi

# Check 3
ps auxwww | grep -v grep | grep "$(/usr/bin/whoami)" | awk '{print $NF}' | grep cron_install_cmssw.sh | grep -v grep
if [ $? -eq 0 ] ; then
   echo ERROR cron_install_cmssw.sh is running
   ps auxwww | grep "$(/usr/bin/whoami)" | grep -v grep
   exit 1
fi

echo INFO backing up crontab and removing
cd $HOME
crontab=crontab.$(date +%s)
crontab -l > $crontab
if [ $? -eq 0 ] ; then
  crontab -r
else
  rm -f $crontab
  crontab=crontab
fi

echo INFO softlinking
#./download_cron_script.sh
cvmfs_server transaction
cd /cvmfs/cms.cern.ch/lhapdf/pdfsets
#rm -f 6.1.5
ln -s $installed $what
#ln -s $what current
#ln -s 6.1a 6.1.5
cd
echo INFO publishing the change
cvmfs_server publish

echo INFO restoring the crontab
crontab $crontab
crontab -l

exit 0
[shared@lxcvmfs40 ~]$ cat crontab
#30     3       *       *       *       cp -r /scratch/shared/* /home/shared/data/
#18 * * * * /home/shared/siteconf/cvmfs_check_siteconf.sh > /home/shared/siteconf/cvmfs_check_siteconf.log 2>&1
2,32 * * * * $HOME/cron_install_cmssw.sh > $HOME/cron_install_cmssw.log 2>&1
