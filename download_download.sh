#!/bin/sh
host=melrose.ihepa.ufl.edu
port=8080
host=cms.rc.ufl.edu
port=8443
wget -q -O download.ascii.db.sh http://${host}:${port}/cmssoft/cvmfs/download.ascii.db.sh
wget -q -O download_cron_script.sh http://${host}:${port}/cmssoft/cvmfs/download_cron_script.sh

chmod a+x download.ascii.db.sh download_cron_script.sh 
./download.ascii.db.sh
./download_cron_script.sh
