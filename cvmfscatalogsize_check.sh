#!/bin/bash
notifytowhom=
sizelimit=100000
dirs_to_check_no_tab=$(find /cvmfs/cms.cern.ch -maxdepth 1 -type d | grep -v /cvmfs/cms.cern.ch$)
dirs_to_check=$(echo $(cat /cvmfs/cms.cern.ch/.cvmfsdirtab))
dirs_to_check=$(for thedir in $dirs_to_check ; do
   echo /cvmfs/cms.cern.ch$thedir | sed 's# #\n#g'
done)

for f in $dirs_to_check_no_tab ; do
    echo $dirs_to_check  | sed 's# #\n#g' | grep -q $f/
    [ $? -eq 0 ] && continue
    dirs_to_check="$dirs_to_check $f" # $(echo $f | sed 's#/cvmfs/cms.cern.ch##')"
done

#echo $dirs_to_check | sed 's# #\n#g'
#echo END OF DEBUG remove exit 0

ndirs=$(echo $dirs_to_check | sed 's# #\n#g' | wc -l)
i=0
for f in $dirs_to_check ; do
   i=$(expr $i + 1)
   [ -f $f/.cvmfscatalog ] || echo Need $f/.cvmfscatalog
   echo $dirs_to_check  | sed 's# #\n#g' | grep -q $f/
   [ $? -eq 0 ] && { echo INFO skipping $f ; continue ; } ;
   if [ -f $HOME/cron_install_cmssw.lock ] ; then
      itime=0
      while : ; do
         itime=$(expr $itime + 1)
         sleep 1m
         [ -f $HOME/cron_install_cmssw.lock ] || break
      done
   fi
   echo "[ $i / $ndirs ]" Doing $f
   ( cd /cvmfs/cms.cern.ch   
     find $f ! -type d | $HOME/cvmfscatalogsize .cvmfsdirtab - > $HOME/logs/cvmfscatalogsize.log
     cd - 2>/dev/null 1>/dev/null
   )
   split_needed=
   for size in $(cat $HOME/logs/cvmfscatalogsize.log | awk '{print $1}') ; do
      [ $size -gt $sizelimit ] && split_needed="$split_needed $(grep ^$size $HOME/logs/cvmfscatalogsize.log | awk '{print $NF}')"
   done
   if [ $(echo $split_needed | wc -w) -eq 0 ] ; then
      echo "[ $i / $ndirs ]" OK
   else
      echo "[ $i / $ndirs ]" INFO $f needs splitting for 
      echo $split_needed | sed 's# #\n#g'
   fi
done

exit 0

for f in $(cat .cvmfsdirtab | sed "s#^/##g") ; do echo $f ; done
#
cat .cvmfsdirtab
/sl*gcc*/cms/cmssw/*
/sl*gcc*/cms/cmssw-patch/*
/fc*gcc*/cms/cmssw/*
/sl*gcc*/external/*/*
/fc*gcc*/external/*/*
/phys_generator/gridpacks/slc*
/osx*gcc*/cms/cmssw/*
/osx*gcc*/external/*/*
/osx*gcc*
/sl*gcc*
/fc*gcc*
/CMS@Home
/COMP
/SITECONF
/cmssw.git.daily
/crab3/sl*gcc*

#find phedex ! -type d | $HOME/cvmfscatalogsize .cvmfsdirtab.new -
#find spacemon-client ! -type d | $HOME/cvmfscatalogsize .cvmfsdirtab.new -
