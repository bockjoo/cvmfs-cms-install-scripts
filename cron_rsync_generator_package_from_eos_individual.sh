#!/bin/bash
#
# Versions
# 0.1.7
# 1.8.7
#
version=1.8.7 # tag=generic-2020-05-13T17:40:17Z

# Configuration
notifytowhom=bockjoo@phys.ufl.edu
source $HOME/cron_install_cmssw.config # notifytowhom
updated_list=/cvmfs/cms.cern.ch/cvmfs-cms.cern.ch-updates

#rsync_source="$HOME/eos2/cms/store/group/phys_generator/cvmfs/gridpacks"
rsync_source="/eos/cms/store/group/phys_generator/cvmfs/gridpacks"
rsync_name="/cvmfs/cms.cern.ch/phys_generator/gridpacks"
rsync_destination="/cvmfs/cms.cern.ch/phys_generator/gridpacks"

what="$(basename $0)"
# Configuration

:
: ######### Main ###################################################
:
# After all the try to mount the EOS, if it is not mounted, try to forceunmount it and exit with error status
if [ ! -d $rsync_source ] ; then
   echo ERROR rsync_source not found eos error
   printf "$(basename $0) $rsync_source not found \n" | mail -s "$(basename $0) ERROR rsync source not found" $notifytowhom
   exit 1
fi

echo INFO looks good $rsync_source exists

# Check if cvmfs is already in transaction
cvmfs_server list  | grep stratum0 | grep -q transaction
if [ $? -eq 0 ] ; then
   printf "$(basename $0) stratum0 in transaction. See \n$(cvmfs_server list)\nThis is strange\n" | mail -s "$(basename $0) stratum0 in transaction" $notifytowhom
   echo ERROR cvmfs server already in transaction
   exit 1   
fi


# Start cvmfs transaction for the dry-run
echo INFO Doing cvmfs_server transaction
cvmfs_server transaction
status=$?
if [ $? -eq 0 ] ; then
   echo INFO transaction OK for $what
else
   echo ERROR transaction check FAILED
   #( cd ; cvmfs_server abort -f ; ) ;
   printf "$(basename $0): 1 cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
   exit 1
fi

# Check if the update is necessary for individual files by dryrunning rsync
echo rsync -arzuvp --delete --dry-run $rsync_source $(dirname $rsync_name)
thelog=$HOME/logs/rsync+generator+package+from+eos.log
rm -f $thelog
rsync -arzuvp --delete --dry-run $rsync_source $(dirname $rsync_name) > $thelog 2>&1
status=$?

# Exit out of transaction since rsync dryrun is logged
echo INFO for now aborting the rsync to rsync only those files that are new
( cd ; cvmfs_server abort -f ; ) ;

# Limit number of gridpacks to be rsynced per cron cycle and Show how many gridpacks need to be rsynced
NGRIDPACKS=120
NEWGRIDPACKS_ONLY= # NEWGRIDPACKS_ONLY=1
echo INFO gridpakcs to be rsynced: $(grep "tar.xz\|tar.gz\|tgz" $thelog | grep "^gridpacks/" | grep -v "_noiter" | wc -l)

# Start the transaction for real
cvmfs_server transaction
status=$?
if [ $? -eq 0 ] ; then
   echo INFO transaction OK for $what
else
   echo ERROR transaction check FAILED
   #( cd ; cvmfs_server abort -f ; ) ;
   printf "$(basename $0): 2 cvmfs_server_transaction_check Failed for $what\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom      
   exit 1
fi

if [ $status -eq 0 ] ; then
   i=0
   publish_needed=0
   # First delete files/directories that are not on EOS anymore
   THOSE_FILES_DELETED=
   ndeletions=$(for f in $(grep ^"deleting gridpacks/" $thelog 2>/dev/null | awk '{print $NF}' | grep gridpacks/ | grep -v /.cvmfscatalog) ; do echo $f ; done | wc -l)
   for f in $(grep ^"deleting gridpacks/" $thelog 2>/dev/null | awk '{print $NF}' | grep gridpacks/ | grep -v /.cvmfscatalog) ; do
       thefile=$(dirname $rsync_name)/$f
       echo DEBUG thefile=$thefile
       echo $thefile | grep -q cvmfscatalog
       [ $? -eq 0 ] && { echo DEBUG file is $thefile ; continue ; } ;
       i=$(expr $i + 1)
       [ $i -gt $NGRIDPACKS ] && break
       if [ -f "$thefile" ] ; then
        ( cd $(dirname $thefile)
          pwd | grep -q /cvmfs/cms.cern.ch/phys_generator/gridpacks
          if [ $? -eq 0 ] ; then
             echo INFO rm -rf $(basename  $thefile) at $(pwd)
             rm -rf $(basename  $thefile)
          fi
        )
        THOSE_FILES_DELETED="$THOSE_FILES_DELETED $thefile"
        publish_needed=1
       else
        echo INFO $thefile does not exist. There is no need for deletion.
       fi
   done

   # Publish as needed
   if [ $publish_needed -eq 1 ] ; then
      time cvmfs_server publish > $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos_individual_delete.log 2>&1
      cvmfs_server transaction
      printf "$(basename $0) INFO $NGRIDPACKS / $ndeletions are deleted from /cvms/cms.cern.ch\nNFILES=$(echo $THOSE_FILES_DELETED | wc -w)\n$(for f in $THOSE_FILES_DELETED ; do echo $f ; done)\n" | mail -s "$(basename $0) INFO files deleted" $notifytowhom
   fi

   files_with_strange_permission=""
   destfiles=""
   i=0
   publish_needed=0
   grep "tar.xz\|tar.gz\|tgz" $thelog | grep "^gridpacks/" | grep -v "_noiter" | grep -v "sys.v\|sys.a" > $HOME/logs/gridpacks_schedule.txt
   #
   # rsync one file at a time individually, thus the name of the script
   #   
   UPDATED_GRIDPACKS=
   for f in $(grep ^gridpacks/ $HOME/logs/gridpacks_schedule.txt) ; do
      if [ ! -f $(dirname $rsync_source)/$f ] ; then
           echo Warning $(dirname $rsync_source)/$f does not exist. Maybe, it is deleted 
           continue
      fi
      destfile=$(dirname $rsync_name)/$f

      # Check if destination directory exists. If not, create. If creation fails for some strange reason, remove the created directory
      if [ ! -d $(dirname $destfile) ] ; then
         echo INFO creating $(dirname $destfile)
         mkdir -p $(dirname $destfile) > $HOME/logs/eos_mkdir_log 2>&1
         grep -q "File exists" $HOME/logs/eos_mkdir_log
         if [ $? -eq 0 ] ; then
            if [ -f $(dirname $destfile) ] ; then
               rm -rf $(dirname $destfile)
               printf "$(basename $0) ERROR failed: $(dirname $destfile) supposed to be a directory. Something went wrong\n" | mail -s "$(basename $0) ERROR failed: mkdir -p $(dirname $destfile) " $notifytowhom
               #echo DRY rm -rf $(dirname $destfile)
               time cvmfs_server publish > $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos.log 2>&1
               [ $? -eq 0 ] || ( cd ; cvmfs_server abort -f ; ) ;
               echo script $0 Done
               #log=$HOME/logs/$(basename $0 | sed 's#\.sh#\.log#g')
               exit 1
            fi
         fi
      fi

      # To upload new files only
      echo DEBUG  NEWGRIDPACKS_ONLY=$NEWGRIDPACKS_ONLY
      if [ $NEWGRIDPACKS_ONLY ] ; then
	  if [ -f $destfile ] ; then
              echo INFO NEWGRIDPACKS_ONLY=$NEWGRIDPACKS_ONLY: $destfile exists so continue
              continue
	  fi
      fi

      # rsync one file
      echo INFO individual rsync : rsync -arzuvp --delete $(dirname $rsync_source)/$f $(dirname $destfile)
      rsync -arzuvp --delete $(dirname $rsync_source)/$f $(dirname $destfile) 2>&1
      if [ $? -ne 0 ] ; then
         printf "$(basename $0) ERROR failed: rsync -arzuvp --delete $(dirname $rsync_source)/$f $(dirname $destfile)\n"
         printf "$(basename $0) ERROR failed: rsync -arzuvp --delete $(dirname $rsync_source)/$f $(dirname $destfile)\n" | mail -s "$(basename $0) ERROR failed: rsync" $notifytowhom
         continue
      fi
      publish_needed=1
      destfiles="$destfiles $destfile"
       
      i=$(expr $i + 1)
      echo "[ $i ] " $(dirname $rsync_name)/$f is a file $publish_needed

      # Check the rsync size
      INDIVIDUAL_RSYNC_SIZE=$(/usr/bin/du -s $(dirname $rsync_name)/$f | awk '{print $1}')
      INDIVIDUAL_RSYNC_SIZE=$(echo "scale=2 ; $INDIVIDUAL_RSYNC_SIZE / 1024 / 1024" | bc | cut -d. -f1)
      [ "x$INDIVIDUAL_RSYNC_SIZE" == "x" ] && INDIVIDUAL_RSYNC_SIZE=0
      if [ $INDIVIDUAL_RSYNC_SIZE -gt $INDIVIDUAL_RSYNC_SIZE_LIMIT ] ; then
         echo Warning INDIVIDUAL_RSYNC_SIZE -gt INDIVIDUAL_RSYNC_SIZE_LIMIT $INDIVIDUAL_RSYNC_SIZE -gt $INDIVIDUAL_RSYNC_SIZE_LIMIT
         printf "$(basename $0) Warning INDIVIDUAL_RSYNC_SIZE > INDIVIDUAL_RSYNC_SIZE_LIMIT : $INDIVIDUAL_RSYNC_SIZE > $INDIVIDUAL_RSYNC_SIZE_LIMIT $(dirname $rsync_name)/$f \n Will not publish the rsync result" | mail -s "$(basename $0) Warning INDIVIDUAL_RSYNC_SIZE > INDIVIDUAL_RSYNC_SIZE_LIMIT" $notifytowhom
      fi

      # Check if there is any strangeness in the permission
      themode=$(/usr/bin/stat -c %a $(dirname $rsync_name)/$f)
      original_file=$(echo $(dirname $rsync_name)/$f | sed "s#$rsync_name#$rsync_source#")
      original_mode=$(/usr/bin/stat -c %a $original_file)
      original_user=$(/usr/bin/stat -c %U $original_file)
      if [ $themode -lt 400 ] ; then
         theuser=$(/usr/bin/stat -c %U $(dirname $rsync_name)/$f)
         files_with_strange_permission="$files_with_strange_permission ${original_mode}+${original_user}+${themode}+${theuser}+$(dirname $rsync_name)/${f}"
      fi
      if [ $(echo $themode | cut -c2-) -lt 40 ] ; then
         theuser=$(/usr/bin/stat -c %U $(dirname $rsync_name)/$f)
         echo "$files_with_strange_permission" | grep -q "+$(dirname $rsync_name)/$f" || files_with_strange_permission="$files_with_strange_permission ${original_mode}+${original_user}+${themode}+${theuser}+$(dirname $rsync_name)/$f"
      fi
      if [ $(echo $themode | cut -c3-) -lt 4 ] ; then
         theuser=$(/usr/bin/stat -c %U $(dirname $rsync_name)/$f)
         echo "$files_with_strange_permission" | grep -q "+$(dirname $rsync_name)/$f" || files_with_strange_permission="$files_with_strange_permission ${original_mode}+${original_user}+${themode}+${theuser}+$(dirname $rsync_name)/$f"
      fi
      if [ $publish_needed -eq 1 ] ; then
         [ $i -gt $NGRIDPACKS ] && break
      fi
      UPDATED_GRIDPACKS="$UPDATED_GRIDPACKS $f"
   done

   # If there are some files that do not have the proper permission, fix it
   if [ "x$files_with_strange_permission" != "x" ] ; then
         printout=$(printf "$(basename $0) Found files with strange permsion\n$(for f in $files_with_strange_permission ; do echo $f ; done)\n")
         for f in $files_with_strange_permission ; do
           thefile=$(echo $f | sed 's#+# #g' | awk '{print $NF}')
           chmod 644 $thefile
         done
         printf "$printout\nStrange files after changing the perm\n$(for f in $files_with_strange_permission ; do ls -al $(echo $f | cut -d+ -f5-) ; done)\n" | mail -s "$(basename $0) Warning Found files with strange permsion" $notifytowhom
   fi
   if [ "x$destfiles" != "x" ] ; then
      printf "$(basename $0) INFO added files\n$(for f in $destfiles ; do echo $f ; done)\n" | mail -s "$(basename $0) INFO gridpack added" $notifytowhom
   fi
   echo INFO check point publish_needed $publish_needed

   # Publish the rsync or not
   if [ $publish_needed -eq 0 ] ; then
      echo INFO publish was not needed, So ending the transaction
      ( cd ; cvmfs_server abort -f ; ) ;
   else
      echo INFO publish necessary
      echo INFO updating $updated_list

      # Update $updated_list
      date_s_now=$(echo $(/bin/date +%s) $(/bin/date -u))
      grep -q "gridpacks $(echo $f | cut -d/ -f2) $(echo $date_s_now | awk '{print $1}')" $updated_list
      if [ $? -eq 0 ] ; then
        echo Warning "gridpacks $(echo $f | cut -d/ -f2) $(echo $date_s_now | awk '{print $1}')" is already in the $updated_list $f
      else
        echo INFO adding "gridpacks $(echo $f | cut -d/ -f2) $(echo $date_s_now | awk '{print $1}')" to $updated_list for $f
      fi
      thestring="gridpacks $(echo $f | cut -d/ -f2) $(echo $date_s_now | awk '{print $1}')"

      echo INFO adding 'phys_generator/gridpacks/slc*/*/*' to /cvmfs/cms.cern.ch/.cvmfsdirtab

      # nested stuff for cvmfs ( to split for the cvmfs performance )
      grep -q /phys_generator/gridpacks/slc /cvmfs/cms.cern.ch/.cvmfsdirtab
      if [ $? -ne 0 ] ; then
         echo '/phys_generator/gridpacks/slc*/*/*' >> /cvmfs/cms.cern.ch/.cvmfsdirtab
      fi

      # fix all wrong perms if any, just an overkill
      echo INFO fixing all wrong perms if any
      n=0
      for f in $(find /cvmfs/cms.cern.ch/phys_generator/gridpacks/ -type f -name "*" -print) ; do
       themode=$(/usr/bin/stat -c %a $f)
       if [ $themode -lt 400 ] ; then
          n=$(expr $n + 1)
          echo chmod 644 $f
          chmod 644 $f
       fi
       if [ $(echo $themode | cut -c2-) -lt 40 ] ; then
          n=$(expr $n + 1)
          echo chmod 644 $f
          chmod 644 $f
       fi
       if [ $(echo $themode | cut -c3-) -lt 4 ] ; then
          n=$(expr $n + 1)
          echo chmod 644 $f
          chmod 644 $f
       fi
      done
      for d in $(find /cvmfs/cms.cern.ch/phys_generator/gridpacks/ -type d -name "*" -print) ; do
       themode=$(/usr/bin/stat -c %a $d)
       if [ $themode -lt 500 ] ; then
          n=$(expr $n + 1)
          echo chmod 755 $d
          chmod 755 $d
       fi
       if [ $(echo $themode | cut -c2-) -lt 50 ] ; then
          n=$(expr $n + 1)
          echo chmod 755 $d
          chmod 755 $d
       fi
       if [ $(echo $themode | cut -c3-) -lt 5 ] ; then
          n=$(expr $n + 1)
          echo chmod 755 $d
          chmod 755 $d
       fi
      done

      # end of fix all wrong perms

      # publish
      echo INFO publishing $rsync_name
      currdir=$(pwd)
      cd
      time cvmfs_server publish > $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos.log 2>&1
      status=$?
      cd $currdir
      if [ $status -eq 0 ] ; then
         printf "$(basename $0) cvmfs_server_publish OK \n$(cat $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos.log | sed 's#%#%%#g')\n"
      else
         ( cd ; echo Warning deleting "$thestring" from $updated_list ; cic_sed_del_line "$thestring" $updated_list ; ) ;
         echo ERROR failed cvmfs_server publish
         printf "$(basename $0) cvmfs_server publish failed\n$(cat $HOME/logs/cvmfs_server+publish+rsync+generator+package+from+eos.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish failed" $notifytowhom
         ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      fi
   fi
else
   echo ERROR failed : rsync -arzuvp $rsync_source $(dirname $rsync_name)
   printf "$(basename $0) ERROR FAILED: rsync -arzuvp $rsync_source $(dirname $rsync_name)\n" | mail -s "$(basename $0) ERROR FAILED rsync" $notifytowhom
   ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
fi
# Sanity check
if [ $(ls $rsync_source | wc -l) -eq $(ls $rsync_name | wc -l) ] ; then
   echo INFO basic sanity check passes : $rsync_source vs $rsync_name
else
   echo Warning basic sanity check fails
   printf "$(basename $0) Checking ls $rsync_source\n$(ls $rsync_source)\nChecking ls $rsync_name \n$(ls $rsync_name) \n" | mail -s "$(basename $0) Warning rsync source and rsync_dir have different content" $notifytowhom
fi

echo script $0 Done
#log=$HOME/logs/$(basename $0 | sed 's#\.sh#\.log#g')
exit 0
