#!/bin/bash
# https://gist.github.com/PerilousApricot/02ff6d127d64948ec4348ea690ff4a5f
# add debugging
set -x

# Change this obviously
MONTH_PATH=/cvmfs/cms.cern.ch/cmssw.git # $(pwd)/test-cmssw.git.monthly
DAY_PATH=/cvmfs/cms.cern.ch/cmssw.git.daily # $(pwd)/test-cmssw.git.daily
status=0
if [[ ! -d $MONTH_PATH ]]; then
    git clone --bare --mirror https://github.com/cms-sw/cmssw $MONTH_PATH
    [ $? -eq 0 ] || status=1
    # GC can leave dangling objects
    pushd $MONTH_PATH
    git config --global gc.auto 0
    [ $? -eq 0 ] || status=2
    git repack -a -d --window=50 --max-pack-size=64M
    [ $? -eq 0 ] || status=3
    popd
fi

# Sync on the 10th
if [[ $(date +"%-d") -eq 10 ]]; then
    pushd $MONTH_PATH
    git fetch
    [ $? -eq 0 ] || status=4
    git repack -a -d --window=50 --max-pack-size=64M
    [ $? -eq 0 ] || status=5
    popd
fi

# Build the daily repo off the monthly repo to ensure the base doesnt 
# change. Since the file content is the same, CVMFS also will only store
# the underlying bytes once
rm -rf "$DAY_PATH"
[ $? -eq 0 ] || status=6
cp -a "$MONTH_PATH" "$DAY_PATH"
[ $? -eq 0 ] || status=7
pushd "$DAY_PATH"
git fetch
[ $? -eq 0 ] || status=8
git repack --max-pack-size=64M
[ $? -eq 0 ] || status=9
popd
exit $status
