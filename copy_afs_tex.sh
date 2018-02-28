#!/bin/bash
cvmfs_server transaction
mkdir   /cvmfs/cms.cern.ch/external
rsync -arzuvp --delete /afs/cern.ch/cms/external/tex /cvmfs/cms.cern.ch/external
touch /cvmfs/cms.cern.ch/external/.README.WWWWHW
touch /cvmfs/cms.cern.ch/external/.cvmfscatalog
touch /cvmfs/cms.cern.ch/external/text/.cvmfscatalog
touch /cvmfs/cms.cern.ch/external/tex/.cvmfscatalog
vi /cvmfs/cms.cern.ch/.cvmfsdirtab 
grep -q '^/external/\*' /cvmfs/cms.cern.ch/.cvmfsdirtab || echo '/external/*' >> /cvmfs/cms.cern.ch/.cvmfsdirtab /cvmfs/cms.cern.ch/.cvmfsdirtab || echo '/external/tex' >> /cvmfs/cms.cern.ch/.cvmfsdirtab
cvmfs_server publish

exit 0

