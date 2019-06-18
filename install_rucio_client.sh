#!/bin/bash -ex

#Rucio version to install, default is latest available in pypi.org
RUCIO_VERSION="latest"

#CVMFS repository name
CVMFS_REPO="cms.cern.ch"

#Use pre-install pip from CVMFS
ARCHITECTURE="slc7_amd64_gcc700"
CMS_PIP_VERSION="9.0.3-pafccj"

#Create a workspace area and download rucio install/setup scripts
WORKSPACE=/tmp/install-rucio
rm -rf $WORKSPACE && mkdir -p $WORKSPACE
cd $WORKSPACE
git clone --depth -1 https://github.com/cms-sw/cms-bot

#Start CVMFS transaction
cvmfs_server transaction
#[ -d /cvmfs/cms.cern.ch/rucio ] || mkdir -p /cvmfs/cms.cern.ch/rucio
#source PIP environment and install rucio-client. Make use of docker container if needed

#DOCKER_CMD="docker run --net=host --rm -t -v /tmp:/tmp -v /cvmfs:/cvmfs -v /home:/home -u $(whoami) cmssw/slc7-installer:latest"
DOCKER_CMD="docker run --net=host --rm -t -v /tmp:/tmp -v /cvmfs:/cvmfs -v /home:/home -u $(whoami) cmssw/slc7-installer:cvcms"
echo INFO Running $DOCKER_CMD sh -c "source /cvmfs/${CVMFS_REPO}/${ARCHITECTURE}/external/py2-pip/${CMS_PIP_VERSION}/etc/profile.d/init.sh ; ${WORKSPACE}/cms-bot/rucio/install.sh -c -v '${RUCIO_VERSION}' -i '/cvmfs/${CVMFS_REPO}/rucio' -C 'file://${WORKSPACE}/cms-bot/rucio/rucio.cfg'"
$DOCKER_CMD sh -c "source /cvmfs/${CVMFS_REPO}/${ARCHITECTURE}/external/py2-pip/${CMS_PIP_VERSION}/etc/profile.d/init.sh ; \
  ${WORKSPACE}/cms-bot/rucio/install.sh -c -v '${RUCIO_VERSION}' -i '/cvmfs/${CVMFS_REPO}/rucio' -C 'file://${WORKSPACE}/cms-bot/rucio/rucio.cfg'"
if [ $? -eq 0 ] ; then
   grep -q "Rucio_Client_0 $ARCHITECTURE" /cvmfs/$CVMFS_REPO/cvmfs-cms.cern.ch-updates || echo "Rucio_Client_0 $ARCHITECTURE" $(date +%s) $(date -u) >> /cvmfs/$CVMFS_REPO/cvmfs-cms.cern.ch-updates
   #echo Success $0 Done
   cvmfs_server publish
   rm -rf $WORKSPACE
   echo Success $0 Done
else
   echo Fail $0
   cvmfs_server abort -f
fi


