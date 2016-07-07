#!/bin/sh
#
# Created by Bockjoo Kim, U of Florida
#
# version=0.1.5
create_host_proxy_download_siteconf_version=0.1.5
which voms-proxy-info 2>/dev/null 1>/dev/null
if [ $? -ne 0 ] ; then
   echo Warning attempting to use the LCG-2 UI
   source /afs/cern.ch/cms/LCG/LCG-2/UI/cms_ui_env.sh
fi
topsiteconf=$1
#x509cert=$HOME/CERTS/cvmfs.ihepa.ufl.edu/hostcert.pem
#x509certkey=$HOME/CERTS/cvmfs.ihepa.ufl.edu/hostkey.pem
#x509proxy=$HOME/.cvmfs.host.proxy
x509proxy=$HOME/.florida.t2.proxy

export X509_USER_PROXY=${x509proxy}
x509proxyvalid="168:30"

notifytowhom=bockjoo@phys.ufl.edu

echo DEBUG topsiteconf=$topsiteconf

#hodi_tmpdir=/tmp
#grid_tmpout="${hodi_tmpdir}/grid_tmpout"
#grid_tmperr="${hodi_tmpdir}/grid_tmperr"
### grid-proxy-init -cert $x509cert -key $x509certkey -valid $x509proxyvalid -out $x509proxy > /dev/null 2> /dev/null
echo DEBUG X509_USER_PROXY $X509_USER_PROXY
echo DEBUG executing voms-proxy-info -timeleft
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
if [ $timeleft -lt 1900 ] ; then #  1800 + 100
if [ ] ; then
   echo INFO creating the grid proxy
   #voms-proxy-init -cert $x509cert -key $x509certkey -out $X509_USER_PROXY --voms cms -valid ${x509proxyvalid} 2>&1
   voms-proxy-init -cert $x509cert -key $x509certkey -out $X509_USER_PROXY -valid ${x509proxyvalid} 2>&1
   if [ $? -ne 0 ] ; then
      printf "$(basename $0) ERROR voms-proxy-init failed\n" | mail -s "$(basename $0) ERROR voms-proxy-init failed" $notifytowhom
      exit 1
   fi
fi # if [ ] ; then
   /usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v srm://srm.ihepa.ufl.edu:8443/srm/v2/server?SFN=/cms/t2/operations/.cmsphedex.proxy  file://$X509_USER_PROXY.copy
   if [ $? -eq 0 ] ; then
      cp $X509_USER_PROXY.copy $X509_USER_PROXY
      voms-proxy-info -all
   else
      printf "$(basename $0) ERROR failed to download $X509_USER_PROXY\n$(/usr/bin/lcg-cp -b -n 1 --vo cms -D srmv2 -T srmv2 -v srm://srm.ihepa.ufl.edu:8443/srm/v2/server?SFN=/cms/t2/operations/.cmsphedex.proxy  file://${X509_USER_PROXY}.copy 2>&1 | sed 's#%#%%#g')n" | mail -s "$(basename $0) ERROR proxy download failed" $notifytowhom
   fi
else
   echo INFO proxy timeleft $timeleft
fi
#timeleft=$(voms-proxy-info -timeleft 2>/dev/null)

echo INFO check $x509proxy
#echo DEBUG using $X509_USER_PROXY
cmsweb_server=cmsweb.cern.ch

# 24DEC2014 Another way of doing it
# Use the proxy /etc/grid-security/certificates
# /usr/bin/curl --capath /etc/grid-security/certificates --cacert $X509_USER_PROXY --cert $X509_USER_PROXY --key $X509_USER_PROXY -X GET "https://${cmsweb_server}/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD" -o /dev/null

#/usr/bin/curl -ks --cert $X509_USER_PROXY --key $X509_USER_PROXY -X GET "https://${cmsweb_server}/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD" -o $topsiteconf/HEAD.tgz

#/usr/bin/curl -ks --cert $x509cert --key $x509certkey -X GET "https://${cmsweb_server}/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD" -o $topsiteconf/HEAD.tgz
#if [ $? -ne 0 ] ; then
#   echo ERROR 1st downloading siteconf HEAD.tgz failed: /usr/bin/curl -ks --cert $x509cert --key $x509certkey -X GET "https://${cmsweb_server}/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD" -o $topsiteconf/HEAD.tgz
   #printf "$(basename $0) ERROR downloading siteconf HEAD.tgz failed\n/usr/bin/curl -ks --cert $X509_USER_PROXY --key $X509_USER_PROXY -X GET \"https://${cmsweb_server}/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD\" -o $topsiteconf/HEAD.tgz\n" | mail -s "$(basename $0) ERROR downloading siteconf HEAD.tgz failed" $notifytowhom
   
   cmsweb_server=cmsweb-testbed.cern.ch
   #/usr/bin/curl -ks --cert $X509_USER_PROXY --key $X509_USER_PROXY -X GET "https://${cmsweb_server}/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD" -o $topsiteconf/HEAD.tgz
   /usr/bin/curl -s -S --cert $X509_USER_PROXY --key $X509_USER_PROXY --cacert $X509_USER_PROXY --capath /etc/grid-security/certificates -X GET "https://${cmsweb_server}/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD" -o $HOME/cms/local_SITECONF/HEAD.tgz
   if [ $? -ne 0 ] ; then
      cmsweb_server=cmsweb.cern.ch
      /usr/bin/curl -s -S --cert $X509_USER_PROXY --key $X509_USER_PROXY --cacert $X509_USER_PROXY --capath /etc/grid-security/certificates -X GET "https://${cmsweb_server}/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD" -o $HOME/cms/local_SITECONF/HEAD.tgz
   fi
   if [ $? -ne 0 ] ; then
      echo ERROR 2nd downloading siteconf HEAD.tgz failed as well:/usr/bin/curl -s -S --cert $X509_USER_PROXY --key $X509_USER_PROXY --cacert $X509_USER_PROXY --capath /etc/grid-security/certificates -X GET "https://${cmsweb_server}/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD" -o /home/cvcms/cms/local_SITECONF/HEAD.tgz #/usr/bin/curl -ks --cert $X509_USER_PROXY --key $X509_USER_PROXY -X GET "https://${cmsweb_server}/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD" -o $topsiteconf/HEAD.tgz
      printf "$(basename $0) ERROR downloading siteconf HEAD.tgz failed\n/usr/bin/curl -s -S --cert $X509_USER_PROXY --key $X509_USER_PROXY --cacert $X509_USER_PROXY --capath /etc/grid-security/certificates -X GET \"https://${cmsweb_server}/gitweb/?p=siteconf/.git;a=snapshot;sf=tgz;h=refs/remotes/origin/HEAD\" -o /home/cvcms/cms/local_SITECONF/HEAD.tgz\n" | mail -s "$(basename $0) ERROR downloading siteconf HEAD.tgz failed" $notifytowhom
      
#      #if [ $? -ne 0 ] ; then
#      echo DEBUG wget -O $topsiteconf/HEAD.tgz http://oo.ihepa.ufl.edu:8080/cmssoft/HEAD.tgz
#      wget -O $topsiteconf/HEAD.tgz http://oo.ihepa.ufl.edu:8080/cmssoft/HEAD.tgz
#      if [ $? -ne 0 ] ; then
#         echo ERROR wget failed for HEAD.tgz from oo.ihepa.ufl.edu
#         printf "$(basename $0) ERROR downloading siteconf HEAD.tgz failed from oo.ihepa.ufl.edu\n" | mail -s "$(basename $0) ERROR downloading siteconf HEAD.tgz failed" $notifytowhom
#      fi
#      ls -al $topsiteconf/HEAD.tgz
      #fi
   else
      echo INFO HEAD.tgz download fine
   fi
#else
#   echo INFO first try was successful.
#fi

echo 
echo INFO checking ls -al $topsiteconf/HEAD.tgz
ls -al $topsiteconf/HEAD.tgz
echo
echo INFO checking file $topsiteconf/HEAD.tgz
file $topsiteconf/HEAD.tgz

exit 0
