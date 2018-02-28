#!/bin/bash
cvmfs_server transaction
mkdir   /cvmfs/cms.cern.ch/external
rsync -arzuvp --delete /afs/cern.ch/cms/external/tex /cvmfs/cms.cern.ch/external
cvmfs_server publish

exit 0

