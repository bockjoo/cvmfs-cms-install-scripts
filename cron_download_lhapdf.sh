#!/bin/sh
#
# Bockjoo Kim, U of Florida
# Purpose:
# It downloads any new lhapdf for CMS and creates a new CMS lhapdf version at the time of the download.
#
# 0.2.2: downloads pdfsets.index as well
# 1.8.7: lhapdfweb_download
#

version=1.8.7
starttime=$(date)
# Source the function first so that variables used in this script can overwrite the ones in the function
source $HOME/functions-cms-cvmfs-mgmt

lhapdf_web=https://lhapdf.hepforge.org/
rsync_source="/cvmfs/sft.cern.ch/lcg/external/lhapdfsets/current"
rsync_destination="/cvmfs/cms.cern.ch/lhapdf"
LHAPDFSET_VERSION_INITIAL=6.2.3a
lhapdfset_versions=$HOME/lhapdfset_versions
# Check if lhapdf_update is yes
[ "$lhapdf_update" == "yes" ] || { echo INFO lhapdf_update=$lhapdf_update ; echo INFO update cron_install_cmssw.config as needed ; exit 0 ; } ;

# First generate the new lhapdf version to use
LHAPDFSET_VERSION_NEW=$(generate_reasonable_lhapdf_version_number $(basename $0) $lhapdfset_versions $lhapdf_web)
[ $? -eq 0 ] || exit 1

grep -q "LHAPDF ${LHAPDFSET_VERSION_NEW}" $updated_list && printf "$(basename $0) ERROR LHAPDF ${LHAPDFSET_VERSION_NEW}" in $updated_list\n" | mail -s "$(basename $0) ERROR LHAPDF ${LHAPDFSET_VERSION_NEW}" in $updated_list" $notifytowhom
grep -q "LHAPDF ${LHAPDFSET_VERSION_NEW}" $updated_list && exit 1
grep -q "$LHAPDFSET_VERSION_NEW" $lhapdfset_versions && printf "$(basename $0) ERROR ${LHAPDFSET_VERSION_NEW}" in $lhapdfset_versions\n" | mail -s "$(basename $0) ERROR ${LHAPDFSET_VERSION_NEW}" in $lhapdfset_versions" $notifytowhom
grep -q "$LHAPDFSET_VERSION_NEW" $lhapdfset_versions && exit 1

# Make sure there is no ${LHAPDFSET_VERSION_NEW}
if [ -d ${rsync_destination}/pdfsets/${LHAPDFSET_VERSION_NEW} ] ; then
   printf "$(basename $0) FAILED: ${rsync_destination}/pdfsets/${LHAPDFSET_VERSION_NEW} exists\n" | mail -s "$(basename $0) FAILED ${LHAPDFSET_VERSION_NEW} exists" $notifytowhom
   exit 1
fi

# Check if cvmfs is already in transaction, shouldn't happen though.
check_if_cvmfs_server_in_transaction $(basename $0) || exit 1

# Put cvmfs in transaction for an rsync dryrun
cvmfs_server_transaction_and_check_status $(basename $0) || exit 1

[ -d $rsync_destination ] || mkdir -p $rsync_destination

# Check if the destination is different from the source
if [ ] ; then
    echo INFO executing rsync -rLptgoDzuv --delete --exclude=\*/.cvmfscatalog --include=current/.cvmfscatalog --exclude=\*@\* --exclude=\*/\*.tar.gz --dry-run ${rsync_source} ${rsync_destination}
    thelog=$HOME/logs/cron_download_lhapdf_rsync.log
    rsync -rLptgoDzuv --delete --exclude=\*/.cvmfscatalog --include=current/.cvmfscatalog --exclude=*/@* --exclude=*/*.tar.gz --dry-run ${rsync_source} ${rsync_destination} > $thelog 2>&1
fi
echo INFO executing rsync -rLptgoDzuv --delete --exclude=*/.cvmfscatalog --exclude=\*@\* --exclude=\*/\*.tar.gz --dry-run ${rsync_source} ${rsync_destination}
thelog=$HOME/logs/cron_download_lhapdf_rsync.log
rsync -rLptgoDzuv --delete --exclude=*/.cvmfscatalog --exclude=*/@* --exclude=*/*.tar.gz --dry-run ${rsync_source} ${rsync_destination} > ${thelog}.DRY 2>&1
status=$?
( cd ; cvmfs_server abort -f ; ) ;

if [ $status -ne 0 ] ; then
   printf "$(basename $0) FAILED: rsync -rLptgoDzuv --delete --exclude=\*/.cvmfscatalog --exclude=\*@\* --exclude=\*/\*.tar.gz --dry-run ${rsync_source} ${rsync_destination}\n$(cat ${thelog}.DRY | sed 's#%#%%#g')\n" | mail -s "$(basename $0) FAILED rsync dry-run" $notifytowhom
   exit 1
fi

# If there is no change, there is no new version to create
#grep -v ^current/$ ${thelog}.DRY | grep -q ^current/ || printf "$(basename $0) DEBUG no change in the PDF set content\n" | mail -s "$(basename $0) DEBUG LHAPDF no change" $notifytowhom
grep -v ^current/$ ${thelog}.DRY | grep -q ^current/ || exit 0


# OK, there was a change. Put cvmfs in transaction
cvmfs_server_transaction_and_check_status $(basename $0) || exit 1

echo INFO LHAPDFSET_VERSION_NEW=$LHAPDFSET_VERSION_NEW

# Notify the start of the new version
printf "$(basename $0) Warn: will create ${rsync_destination}/pdfsets/${LHAPDFSET_VERSION_NEW} \n" | mail -s "$(basename $0) Warn creating LHAPDF ${LHAPDFSET_VERSION_NEW}" $notifytowhom

# Create the new version at the official area of the new version
echo INFO executing rsync -rLptgoDzuv --delete --exclude=.cvmfscatalog --exclude=@\* --exclude=\*.tar.gz ${rsync_source}/ ${rsync_destination}/pdfsets/${LHAPDFSET_VERSION_NEW}
rsync -rLptgoDzuv --delete --exclude=.cvmfscatalog --exclude=@* --exclude=*.tar.gz ${rsync_source}/ ${rsync_destination}/pdfsets/${LHAPDFSET_VERSION_NEW} > $thelog 2>&1
if [ $? -ne 0 ] ; then
   echo ERROR rsync -rLptgoDzuv --delete --exclude=.cvmfscatalog --exclude=@* --exclude=*.tar.gz ${rsync_source}/ ${rsync_destination}/pdfsets/${LHAPDFSET_VERSION_NEW}
   printf "$(basename $0) FAILED: rsync -rLptgoDzuv --delete --exclude=.cvmfscatalog --exclude=@\* --exclude=\*.tar.gz --dry-run ${rsync_source}/ ${rsync_destination}/pdfsets/${LHAPDFSET_VERSION_NEW}\n$(cat $thelog | sed 's#%#%%#g')\n" | mail -s "$(basename $0) FAILED rsync for $LHAPDFSET_VERSION_NEW" $notifytowhom
   ( cd ; cvmfs_server abort -f ; ) ;
   exit 1
fi

# Update ${rsync_destination}
echo INFO executing rsync -rLptgoDzuv --delete --exclude=\*/.cvmfscatalog --exclude=\*/@\* --exclude=\*/\*.tar.gz ${rsync_source} ${rsync_destination}
rsync -rLptgoDzuv --delete --exclude=*/.cvmfscatalog --exclude=*/@* --exclude=*/*.tar.gz ${rsync_source} ${rsync_destination} > $thelog.update 2>&1
if [ $? -ne 0 ] ; then
   echo UNDO  rsync for ${LHAPDFSET_VERSION_NEW} 
   ( cd ${rsync_destination}/pdfsets ; rm -rf ${LHAPDFSET_VERSION_NEW} ; ) ;   
   echo ERROR rsync -rLptgoDzuv --delete --exclude=*/.cvmfscatalog --exclude=*/@* --exclude=*/*.tar.gz ${rsync_source} ${rsync_destination}
   printf "$(basename $0) FAILED: rsync -rLptgoDzuv --delete --exclude=\*/.cvmfscatalog --exclude=\*@\* --exclude=\*/\*.tar.gz --dry-run ${rsync_source} ${rsync_destination}\n$(cat $thelog.update | sed 's#%#%%#g')\n" | mail -s "$(basename $0) FAILED rsync update for ${rsync_destination}/current" $notifytowhom
   ( cd ; cvmfs_server abort -f ; ) ;
   exit 1
fi

endtime=$(date)
## Test
#( cd ; cvmfs_server abort -f ; ) ;
#printf "$(basename $0) DEBUG start=$starttime end=$endtime \n$(cat $lhapdfset_versions)\n$(cat $thelog | sed 's#%#%%#g') \nUpdate log\n$(cat $thelog | sed 's#%#%%#g')\n" | mail -s "$(basename $0) DEBUG Check Debug Run" $notifytowhom
## Test
#exit 0

echo INFO updating the $updated_list with ${LHAPDFSET_VERSION_NEW}
grep -q "LHAPDF ${LHAPDFSET_VERSION_NEW}" $updated_list || echo "LHAPDF ${LHAPDFSET_VERSION_NEW} $(date +%s) $(date)" >> $updated_list
grep -q "$LHAPDFSET_VERSION_NEW" $lhapdfset_versions || echo "$LHAPDFSET_VERSION_NEW" >> $lhapdfset_versions

cvmfs_server publish 2>&1
if [ $? -ne 0 ] ; then
   printf "$(basename $0) ERROR: Status=$status failed to publish ${LHAPDFSET_VERSION_NEW}\n$(cat $thelog | sed 's#%#%%#g') \nUpdate log\n$(cat $thelog | sed 's#%#%%#g')\n" | mail -s "$(basename $0) ERROR publication failure: LHAPDF ${LHAPDFSET_VERSION_NEW}" $notifytowhom
   exit 1
fi
printf "$(basename $0) INFO: Status=$status start=$starttime end=$endtime. We created ${rsync_destination}/pdfsets/${LHAPDFSET_VERSION_NEW}\n$(cat $thelog | sed 's#%#%%#g') \nUpdate log\n$(cat $thelog | sed 's#%#%%#g')\n" | mail -s "$(basename $0) INFO LHAPDF ${LHAPDFSET_VERSION_NEW} created" $notifytowhom

echo script $(basename $0) $status Done


exit $status

# Variables used in this script
workdir=/tmp/lhapdf
thehome=$HOME
lhapdf_top=$VO_CMS_SW_DIR/lhapdf
reference_list=$HOME/lhapdf_list.txt
ntry=5
THELOG=$HOME/logs/cron_download_lhapdf.log

min_relnum=5009001 # minim release number is 5.9.1
min_relnum=600100000 # minim release number is 6.1.000
min_relnum=6001000 # minim release number is 6.1.0

lhapdfweb_download="http://www.hepforge.org/archive/lhapdf/"
lhapdfweb_download="https://lhapdf.hepforge.org/downloads?f="
lhapdfweb_download="http://oo.ihepa.ufl.edu:8080/lhapdf/"

lhapdfweb=http://www.hepforge.org/archive/lhapdf

# Format: dest This should be a real release + .a or .b or .c or .d etc # /cvmfs/cms.cern.ch/lhapdf/pdfsets/<lhapdfweb_update>
lhapdfweb_updates="6.1.4b 6.1.4c 6.1.a 6.1.b 6.1.c 6.1.d 6.1.e 6.1.f 6.1.g 6.1.h 6.2 6.2.1 6.2.1.a 6.2.1.b 6.2.1.c"

# Format: dest|symlink
needs_softlinks="6.1.b|6.1.5a 6.1.c|6.1.5b 6.1.d|6.1.5d 6.1.e|6.1.5e 6.1.f|6.1.5f 6.1.g|6.1.6 6.1.h|6.1.6a 6.2|6.2.0a 6.2.1|6.2.1a 6.2.1.a|6.2.1b 6.2.1.b|6.2.1c 6.2.1.c|6.2.1d" # 6.1.6 -> 6.1.g
previous_release=$(echo $lhapdfweb_updates | awk '{print $(NF-1)}')

:
: Main
:

for v in $lhapdfweb_updates ; do
   grep -q ^${v}$ $reference_list
   [ $? -eq 0 ] || echo ${v} >> $reference_list
done


[ -d $workdir ] || mkdir -p $workdir

echo INFO Starting $(basename $0) LOG=$THELOG

cvmfs_server list  | grep stratum0 | grep -q transaction
if [ $? -eq 0 ] ; then
   echo ERROR cvfsm server already in transaction
   exit 1
fi
cvmfs_server transaction 2>&1
[ $? -eq 0 ] || { printf "$(basename $0) ERROR cvmfs_server transaction failed\n$(cat $THELOG | sed 's#%#%%#g')\nChecking ps\n$(ps auxwww | sed 's#%#%%#g' | grep $(/usr/bin/whoami) | grep -v grep)\n" | mail -s "$(basename $0) cvmfs_server transaction lock failed" $notifytowhom ; exit 1 ; } ;

begin_transaction=1
releases=$(wget --no-check-certificate -q -O- ${lhapdfweb}/pdfsets/ | grep folder.gif | grep -v current | sed 's#href="#|#g' | cut -d\| -f2 | cut -d/ -f1)
for v in $releases $lhapdfweb_updates ; do
   if [ $begin_transaction -eq 0 ] ; then
     cvmfs_server transaction 2>&1
     [ $? -eq 0 ] || { printf "$(basename $0) ERROR cvmfs_server transaction failed while doing lhapdf v=$v\n$(cat $THELOG | sed 's#%#%%#g')\nChecking ps\n$(ps auxwww | sed 's#%#%%#g' | grep $(/usr/bin/whoami) | grep -v grep)\n" | mail -s "$(basename $0) cvmfs_server transaction lock failed" $notifytowhom ; exit 1 ; } ;
     begin_transaction=1
   fi
   if [ -f "$reference_list" ] ; then
      grep -q "^${v}$" $reference_list
      [ $? -eq 0 ] || { echo INFO $v not in $reference_list ; continue ; } ;
   else
      echo ERROR not available : $reference_list
      printf "$(basename $0) ERROR not available : $reference_list" | mail -s "$(basename $0) ERROR $reference_list not available" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      exit 1
   fi
   #v=$(echo $reltgz | sed 's#lhapdf-##g' | sed 's#.tar.gz##g' | sed 's#[A-Z]##g' | sed 's#[a-z]##g')
   major=$(echo $v | cut -d. -f1)  # 6.1.a # 6
   minor=$(echo $v | cut -d. -f2)  # 6.1.a # 1
   subv=$(echo $v | cut -d. -f3)   # 6.1.a # a
   #echo DEBUG major=$major minor=$minor subv=$subv
   [ "X$major" == "X" ] && major=0
   [ "X$minor" == "X" ] && minor=0
   #[ "X$subv" == "X" ] && subv=0
   #echo DEBUG reltgz=$reltgz major=$major minor=$minor subv=$subv 
   if [ "x$subv" == "x" ] && [ $major -gt 5 ] ; then
      relnum_origin=$(expr $major \* 1000000 + $minor \* 1000 )
      #echo DEBUG 1 relnum=$relnum
      relnum=${relnum_origin}000
      #echo DEBUG 2 relnum=$relnum
   else
      [ "x$subv" == "x" ] && subv=0
      subv=$(echo $subv | sed "s#[a-z]##g" | sed "s#[A-Z]##g")
      if [ "x$subv" == "x" ] ; then
         relnum=$(expr $major \* 1000000 + $minor \* 1000 + 0)
      else
         relnum=$(expr $major \* 1000000 + $minor \* 1000 + $subv)
      fi
      #relnum_origin=$relnum
   fi
   #relnum=$(expr $major \* 1000000 + $minor \* 1000 + $subv)
   #if [ "x$subv" == "x" ] ; then
   #   if [ $major -gt 5 ] ; then
   #      relnum=${relsum}000
   #   fi
   #fi
   #echo DEBUG relnum=$relnum
   [ $relnum -lt $min_relnum ] && continue

   # 0 download it
   #echo DEBUG relnum=$relnum 
   reldir=$v # (echo $reltgz | sed 's#.tar.gz##')
   relv=$(echo $reldir | cut -d- -f2-)
   dest=pdfsets/$relv
   echo DEBUG dest = $dest
   echo DEBUG major=$major minor=$minor subv=$subv relnum=$relnum reldir=$reldir relv=$relv dest=$dest

   grep -q "lhapdf $dest " $updated_list
   if [ $? -eq 0 ] ; then
      echo INFO $dest is already in the cvmfs
      continue
   fi

   grep -q "lhapdf ${dest}a " $updated_list
   if [ $? -eq 0 ] ; then
      echo INFO ${dest} is already in the cvmfs
      continue
   fi

   if [ -d $lhapdf_top/${dest}a ] ; then
      echo INFO ${dest} "( ${dest}a ) " is already in the cvmfs
      continue
   fi

   dest_nested_catalog=${dest}

   echo "${dest}" | cut -d/ -f2 | grep -q "[a-z]\|[A-Z]"
   if [ $? -eq 0 ] ; then # if the hard directory has an alphabet
   #if [ $? -eq 0 ] ; then
   #   dest=pdfsets/$(echo $relv | sed "s#[a-z]##g" | sed "s#[A-Z]##g")
   #fi

     if [ "x$subv" == "x" ] ; then
        echo dest pdfsets/$major.$minor
        dest=pdfsets/${major}.${minor}
     else
        echo dest pdfsets/$major.$minor.$subv
        dest=pdfsets/${major}.${minor}.${subv}
    fi
   fi

   echo INFO we will get the tarball from ${lhapdfweb_download}$dest to /cvmfs/cms.cern.ch/lhapdf/$dest_nested_catalog # if it was 6.2.1.a, it will get from 6.2.1 

   # 
   #
   # 6.1.4 and 6.1.4b are same for dest and dest_nested_catalog so far
   #
   # dest is 6.1.4 or the like and dest_nested_catalog is 6.1.4b or the like from lhapdfweb_updates
   # 
   dest_temp=
   dest_saved=
   echo INFO checking if it is a soft-link
   if [ -L $lhapdf_top/$dest_nested_catalog ] ; then
      dest_saved=$lhapdf_top/$dest_nested_catalog
      dest_temp=$lhapdf_top/${dest_nested_catalog}.temp
      mv $lhapdf_top/$dest $lhapdf_top/${dest_nested_catalog}.temp
   fi
   printf "$(basename $0) INFO starting lhapdf download for $v\n" | mail -s "$(basename $0) INFO lhapdf $v download started" $notifytowhom

   #files=$(wget -q --no-check-certificate -O- ${lhapdfweb_download}$dest | grep "pdfsets.index\|tar.gz" | sed 's#href="#|#g' | cut -d\| -f2 | cut -d\" -f1 | cut -d= -f2)
   #1.0.6.2.1.c files=$(wget -q --no-check-certificate -O- ${lhapdfweb_download}$dest | grep "pdfsets.index\|tar.gz" | sed 's#href="#|#g' | cut -d/ -f3 | cut -d\" -f1 | grep -v \\.\\.tar.gz | sort -u)
   files=$(wget -q --no-check-certificate -O- ${lhapdfweb_download}$dest | grep "pdfsets.index\|tar.gz" | sed 's#href="#|#g' | cut -d\| -f2 | cut -d\" -f1 | cut -d/ -f3 | grep -v \\.\\.tar.gz | sort -u)
   #http://www.hepforge.org/archive/lhapdf/pdfsets/6.2.1
   #https://lhapdf.hepforge.org/downloads?f=pdfsets/6.2.1
   i=0
   nfiles=$(echo $files | wc -w)
   nfiles_half=$(expr $nfiles / 2)
   for f in $files ; do
      i=$(expr $i + 1)
      ( [ -d $lhapdf_top/$dest_nested_catalog ] || { echo INFO creating $lhapdf_top/$dest_nested_catalog ; mkdir -p $lhapdf_top/$dest_nested_catalog ; } ;
        j=0
        while [ $j -lt $ntry ] ; do
           echo INFO "[ $i ] Trial=$j Downloading $f"
           # example: wget --no-check-certificate -O /cvmfs/cms.cern.ch/lhapdf/pdfsets/6.1.h/HERAPDF20_NNLO_ALPHAS_118.tar.gz http://www.hepforge.org/archive/lhapdf/pdfsets/6.1/HERAPDF20_NNLO_ALPHAS_118.tar.gz
           wget -q --no-check-certificate -O $lhapdf_top/${dest_nested_catalog}/$f  ${lhapdfweb_download}$dest/$f
           status=$?
           [ $status -eq 0 ] && break
           j=$(expr $j + 1)
        done
        # v 0.3.2 take the one from previous release if permission error
        if [ $status -ne 0 ] ; then
           echo DEBUG checking $lhapdf_top/pdfsets/${previous_release}/$(echo $f | sed 's#\.tar\.gz##')
           if [ -d $lhapdf_top/pdfsets/${previous_release}/$(echo $f | sed 's#\.tar\.gz##') ] ; then
              echo Warning it exists in $previous_release
              printf "$(basename $0) ERROR failed : $f\nTry wget -q --no-check-certificate -O $lhapdf_top/${dest_nested_catalog}/$f  ${lhapdfweb_download}$dest/$f\nCould be due to a permission error\n$(cat $THELOG | sed 's#%#%%#g')" | mail -s "ERROR: $(basename $0) Downloading failed" $notifytowhom
              if [ ] ; then
                 echo Warning creating the artificial one
                 ( cd $lhapdf_top/pdfsets/${previous_release} ; tar czvf $lhapdf_top/${dest_nested_catalog}/$f $(echo $f | sed 's#\.tar\.gz##') ; exit $? )
                 status=$?
              fi # if [ ] ; then
           fi
           exit $status
        fi # v 0.3.2 take the one from previous release if permission error
        #cd $lhapdf_top/${dest_nested_catalog} # new 22JUL2015 0.2.4
        echo INFO "[ $i ] Status $status"
        /usr/bin/file $lhapdf_top/${dest_nested_catalog}/$f | grep -q "gzip compressed data"
        if [ $? -eq 0 ] ; then
           cd $lhapdf_top/$dest_nested_catalog
           echo INFO "[ $i ] Unpacking"
           cd $lhapdf_top/${dest_nested_catalog}
           df_h_info=$(df -h .) ; echo $df_h_info  counter: $i -eq $nfiles_half -o $i -eq 646 ; echo $(df -h /) ; echo $(df -h /home/cvcms) echo $(df -h /srv/cvmfs/cms.cern.ch) ; df -h
           tar xzf $f
           status=$(expr $status + $?)
           rm -f $lhapdf_top/${dest_nested_catalog}/$f
           cd -
        else
           echo INFO "[ $i ] $f is not a gzip compressed data"
           echo DEBUG checking $lhapdf_top/${dest_nested_catalog}/$f
           ls -al $lhapdf_top/${dest_nested_catalog}/$f
           #status=$(expr $status + 1)
        fi
        echo INFO "[ $i ] Status $status"
        exit $status        
      )
      if [ $? -ne 0 ] ; then
          printf "$(basename $0) ERROR failed : $f\nTry wget -q --no-check-certificate -O $lhapdf_top/${dest_nested_catalog}/$f  ${lhapdfweb_download}$dest/$f\n$(cat $THELOG | sed 's#%#%%#g')" | mail -s "$(basename $0) Unpacking failed" $notifytowhom

         # 0.1.6 20NOV2014 soft-link manipulation
         if [ "x$dest_temp" != "x" ] ; then
            echo INFO soft-link manipulation necessary
            if [ -L $dest_temp ] ; then
               if [ "xdest_saved" == "x" ] ; then
                  echo INFO $dest_saved is empty strange
                  printf "$(basename $0) ERROR $dest_saved is empty strange : $f" | mail -s "$(basename $0) $dest_saved is empty strange" $notifytowhom
               else
                  if [ -L $dest_saved ] ; then
                     echo INFO $dest_saved is alreay a soft-link strange
                     printf "$(basename $0) ERROR $dest_saved is already a soft-link strange : $f" | mail -s "$(basename $0) $dest_saved is already a sfot-link strange" $notifytowhom
                  else
                     echo INFO restoring the soft-link
                     mv $dest_temp $dest_saved
                     printf "$(basename $0) INFO restored $dest_saved\nCheck ls -al follows\n$(ls -al $dest_saved)\n " | mail -s "$(basename $0) $dest_saved restored" $notifytowhom
                  fi
               fi
            else
              echo INFO $dest_temp is not a soft-link strange
              printf "$(basename $0) ERROR $dest_temp is not a soft-link strange : $f" | mail -s "$(basename $0) $dest_temp is not a soft-link" $notifytowhom
            fi
         else
            echo INFO soft-link manipulation unnecessary
         fi
         # 0.1.6 20NOV2014 soft-link manipulation

         ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f

         exit 1
      fi

      # DELETE tarball
      /usr/bin/file $lhapdf_top/${dest_nested_catalog}/$f | grep -q "gzip compressed data"
      if [ $? -eq 0 ] ; then
       rm -f $lhapdf_top/${dest_nested_catalog}/$f
       if [ $? -ne 0 ] ; then
         echo ERROR failed : $f
         ( cd $lhapdf_top ; echo rm -rf $dest_nested_catalog ; rm -rf $dest_nested_catalog ; ) ;
         printf "$(basename $0) ERROR failed : $f" | mail -s "cron_download_lhapdf_new failed" $notifytowhom

         # 0.1.6 20NOV2014 soft-link manipulation
         if [ "x$dest_temp" != "x" ] ; then
            echo INFO soft-link manipulation necessary
            if [ -L $dest_temp ] ; then
               if [ "xdest_saved" == "x" ] ; then
                  echo INFO $dest_saved is empty strange
                  printf "$(basename $0) ERROR $dest_saved is empty strange : $f" | mail -s "$(basename $0) $dest_saved is empty strange" $notifytowhom
               else
                  if [ -L $dest_saved ] ; then
                     echo INFO $dest_saved is alreay a soft-link strange
                     printf "$(basename $0) ERROR $dest_saved is already a soft-link strange : $f" | mail -s "$(basename $0) $dest_saved is already a sfot-link strange" $notifytowhom
                  else
                     echo INFO restoring the soft-link
                     mv $dest_temp $dest_saved
                     printf "$(basename $0) INFO restored $dest_saved\nCheck ls -al follows\n$(ls -al $dest_saved)\n " | mail -s "$(basename $0) $dest_saved restored" $notifytowhom
                  fi
               fi
            else
              echo INFO $dest_temp is not a soft-link strange
              printf "$(basename $0) ERROR $dest_temp is not a soft-link strange : $f" | mail -s "$(basename $0) $dest_temp is not a soft-link" $notifytowhom
            fi
         else
            echo INFO soft-link manipulation unnecessary
         fi
         # 0.1.6 20NOV2014 soft-link manipulation
         ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f

         exit 1
       fi
      fi # if [ $? -eq 0 ] ; then
      # half-way through publish it

      if [ $i -eq $nfiles_half -o $i -eq 646 ] ; then
         echo INFO $i is $nfiles_half : halfway through
         dirnow=$(pwd)
         cd
         time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish+lhapdf_halfway.log
         status=$?
         #cd $dirnow
         if [ $status -eq 0 ] ; then
            echo INFO cvmfs_server publish fine
            cvmfs_server transaction 2>&1
            cd $dirnow
         else
            #printf "$(basename $0) cvmfs_server_publish OK \n$(cat $HOME/logs/cvmfs_server+publish+lhapdf.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish for $dest OK" $notifytowhom
            #begin_transaction=0
            #cp $THELOG $HOME/logs/cron_download_lhapdf+${dest_nested_catalog}.log
            #else
            echo ERROR failed cvmfs_server publish
            printf "$(basename $0) cvmfs_server publish failed\n$(cat $HOME/logs/cvmfs_server+publish+lhapdf_halfway.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish failed" $notifytowhom
            ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
            exit 1
         fi
      fi
   done

   echo INFO So far so good check $lhapdf_top/$dest_nested_catalog


   # 0.1.6 20NOV2014 soft-link manipulation
   if [ "x$dest_temp" != "x" ] ; then
            echo INFO soft-link manipulation necessary
            if [ -L $dest_temp ] ; then
               if [ "xdest_saved" == "x" ] ; then
                  echo INFO $dest_saved is empty strange
                  printf "$(basename $0) ERROR $dest_saved is empty strange : $f" | mail -s "$(basename $0) $dest_saved is empty strange" $notifytowhom
               else
                  if [ -L $dest_saved ] ; then
                     echo INFO $dest_saved is alreay a soft-link strange
                     printf "$(basename $0) ERROR $dest_saved is already a soft-link strange : $f" | mail -s "$(basename $0) $dest_saved is already a sfot-link strange" $notifytowhom
                  else
                     if [ -d ${lhapdf_top}/${dest}a ] ; then
                        rm -rf ${lhapdf_top}/${dest}
                        mv $dest_temp $dest_saved
                        printf "$(basename $0) ERROR strange ${lhapdf_top}/${dest}a exists \nrestored $dest_saved\nCheck ls -al follows\n$(ls -al $dest_saved)\n " | mail -s "$(basename $0) $dest_saved restored" $notifytowhom
                        ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
                        exit 1
                     else
                        dest_nested_catalog=${dest}a
                        mv ${lhapdf_top}/${dest} ${lhapdf_top}/${dest}a
                        if [ -f ${lhapdf_top}/checksum_pdfsets_${relv}.txt ] ; then
                           cp ${lhapdf_top}/checksum_pdfsets_${relv}.txt ${lhapdf_top}/checksum_pdfsets_${relv}a.txt
                        fi
                        echo INFO restoring the soft-link
                        mv $dest_temp $dest_saved
                        printf "$(basename $0) INFO mv ${lhapdf_top}/${dest} ${lhapdf_top}/${dest}a \nrestored $dest_saved\nCheck ls -al follows\n$(ls -al $dest_saved)\n " | mail -s "$(basename $0) $dest_saved restored" $notifytowhom
                     fi
                  fi
               fi
            else
              echo INFO $dest_temp is not a soft-link strange
              printf "$(basename $0) ERROR $dest_temp is not a soft-link strange : $f" | mail -s "$(basename $0) $dest_temp is not a soft-link" $notifytowhom
            fi
   else
            echo INFO soft-link manipulation unnecessary
   fi
   # 0.1.6 20NOV2014 soft-link manipulation

   # At this point, dest is 6.1.4 and dest_nested_catalog=6.1.4a 
   #                dest=6.1 dest_nested_catalog=6.1.5a
   echo DEBUG Check point dest=$dest dest_nested_catalog=${dest_nested_catalog}
   #    DEBUG Check point dest=pdfsets/6.2 dest_nested_catalog=pdfsets/6.2

   ( echo INFO creating the checksum file
     cd ${lhapdf_top}/$dest_nested_catalog
     realv=$(echo $dest_nested_catalog | cut -d/ -f2)
     rm -f ${lhapdf_top}/checksum_pdfsets_${realv}.txt
     touch ${lhapdf_top}/checksum_pdfsets_${realv}.txt
     for f in $(find ${lhapdf_top}/$dest_nested_catalog -type f -name "*" -print) ; do
          echo DEBUG $f
          echo INFO ensuring permission
          if [ $(/usr/bin/stat --format=%a $f) -eq 644 ] ; then
             : # good
          else
             perm_original=$(/usr/bin/stat --format=%a $f)
             perm_file=644
             if [ "x$(/usr/bin/stat --format=%F $f)" == "xregular file" ] ; then
                echo Warning chaning the permssion for $f from $perm_original to $perm_file
                chmod $perm_file $f
                printf "$(basename $0) Warning chaning the permssion for $f from $perm_original to $perm_file\n" | mail -s "$(basename $0) Permission corrected $(basename $f)" $notifytowhom
             else
                echo Error not chaning the permssion for $f from $perm_original to $perm_file
                #chmod $perm_file $f
                printf "$(basename $0) Error not chaning the permssion for $f from $perm_original to $perm_file\n$f is not a regular file" | mail -s "$(basename $0) Permission needs to be corrected $(basename $f)" $notifytowhom
             fi
          fi
          thedir=$(dirname $f)
          if [ $(/usr/bin/stat --format=%a $thedir) -eq 755 ] ; then
             : # good
          else
             perm_original=$(/usr/bin/stat --format=%a $thedir)
             perm_file=755
             if [ "x$(/usr/bin/stat --format=%F $thedir)" == "xdirectory" ] ; then                
                echo Warning chaning the permssion for $thedir from $perm_original to $perm_file
                chmod $perm_file $thedir
                printf "$(basename $0) Warning chaning the permssion for $thedir from $perm_original to $perm_file\n" | mail -s "$(basename $0) Permission corrected $(basename $thedir)" $notifytowhom
             else
                echo Error not chaning the permssion for $thedir from $perm_original to $perm_file
                printf "$(basename $0) Error not chaning the permssion for $thedir from $perm_original to $perm_file\n$thedir is not a directory" | mail -s "$(basename $0) Permission needs to be corrected $(basename $thedir)" $notifytowhom
             fi
          fi
          
          grep -q $f ${lhapdf_top}/checksum_pdfsets_${realv}.txt
	  if [ $? -ne 0 ] ; then
             echo DEBUG calculating checksum for $f
             #    DEBUG calculating checksum for /cvmfs/cms.cern.ch/lhapdf/pdfsets/6.2/HERAPDF20_NLO_VAR/HERAPDF20_NLO_VAR_0001.dat
             /usr/bin/cksum $f >> ${lhapdf_top}/checksum_pdfsets_${realv}.txt
          fi
     done
   )

   #   if [ $? -eq 0 ] ; then
   # 1 create the nested catalog
   echo INFO creating the nested catalog
   ls -al ${lhapdf_top}/${dest_nested_catalog}/.cvmfscatalog 2>/dev/null 1>/dev/null ;
   if [ $? -eq 0 ] ; then
      echo INFO ${lhapdf_top}/${dest_nested_catalog}/.cvmfscatalog exists
   else
      echo INFO creating ${lhapdf_top}/${dest_nested_catalog}/.cvmfscatalog
      touch ${lhapdf_top}/${dest_nested_catalog}/.cvmfscatalog
   fi

   # 2 add it to the updated list
   echo INFO adding it to the updated list 
   grep -q "lhapdf $dest_nested_catalog " $updated_list
   if [ $? -eq 0 ] ; then
      echo Warning lhapdf $dest_nested_catalog is already in the $updated_list
   else
     echo INFO adding lhapdf $dest_nested_catalog to $updated_list
     echo lhapdf $dest_nested_catalog $(/bin/date +%s) $(/bin/date -u) >> $updated_list
   fi

   # 3 add a README if it does not exist
   #if [ ! -f $VO_CMS_SW_DIR/README.lhapdf ] ; then
   echo INFO creating a README
   echo This is a README for $VO_CMS_SW_DIR/lhapdf. > $VO_CMS_SW_DIR/README.lhapdf
   #      echo The distribution does not include NNPDF\*_1000.LHgrid. >> $VO_CMS_SW_DIR/README.lhapdf
   echo Please compare ${lhapdf_top}/checksum_pdfsets_\*.txt with what you see on the cvmfs client >> $VO_CMS_SW_DIR/README.lhapdf
   echo with the job execution that uses lhapdf. >> $VO_CMS_SW_DIR/README.lhapdf
   echo Please also refer to the original download page: >> $VO_CMS_SW_DIR/README.lhapdf
   echo $lhapdfweb/pdfsets >> $VO_CMS_SW_DIR/README.lhapdf
   echo See also $VO_CMS_SW_DIR/cvmfs-cms.cern.ch-updates >> $VO_CMS_SW_DIR/README.lhapdf


   #fi

   # 4.0 create current
   currdir=$(pwd)
   cd $(dirname $VO_CMS_SW_DIR/lhapdf/$dest_nested_catalog)
   rm -f current
   ln -s $(basename $dest_nested_catalog) current
   for softlink in $needs_softlinks ; do
       echo $softlink | grep -q "${v}|"
       if [ $? -eq 0  ] ; then 
          installed=${v}
          what=$(echo $softlink | cut -d\| -f2)
          currdir=$(pwd)
          create_lhapdf_softlink ${v} $what
          if [ $? -eq 0 ] ; then
            printf "$(basename $0) Success create_lhapdf_softlink $v $what\ndest=$dest\ndest_nested_catalog=$dest_nested_catalog " | mail -s "$(basename $0) create_lhapdf_softlink Success" $notifytowhom
          else
            printf "$(basename $0) ERROR create_lhapdf_softlink $v $what failed\ndest=$dest\ndest_nested_catalog=$dest_nested_catalog " | mail -s "$(basename $0) create_lhapdf_softlink failed" $notifytowhom
          fi
          cd $currdir
          break
       fi
   done
   echo INFO $lhapdf_top/${dest_nested_catalog}/pdfsets.index
   ls $lhapdf_top/${dest_nested_catalog}/pdfsets.index
   status=$?
   last_softlink=$(echo $needs_softlinks | awk '{print $NF}')
   echo INFO last_softlink=$last_softlink
   [ $(echo $last_softlink | sed 's#|# #' | wc -w) -eq 2 ] || { echo ERROR $(echo $last_softlink | sed 's#|# #' | wc -w) -eq 2 ; status=1 ; } ;
   [ -d $lhapdf_top/pdfsets/$(echo $last_softlink | sed 's#|# #' | awk '{print $1}') ] || { echo ERROR $lhapdf_top/pdfsets/$(echo $last_softlink | sed 's#|# #' | awk '{print $1}') does not exist ; status=1 ; } ;
   [ -d $lhapdf_top/pdfsets/$(echo $last_softlink | sed 's#|# #' | awk '{print $2}') ] || { echo ERROR $lhapdf_top/pdfsets/$(echo $last_softlink | sed 's#|# #' | awk '{print $2}') does not exist ; status=1 ; } ;
   if [ $status -ne 0 ] ; then
      echo ERROR failed $lhapdf_top/${dest_nested_catalog}/pdfsets.index does not exist
      printf "$(basename $0) $lhapdf_top/${dest_nested_catalog}/pdfsets.index does not exist \n$(cat $HOME/cvmfs_server+publish+lhapdf.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) ERROR no pdfsets.index found" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      exit 1
   fi
   # 4 publish
   echo INFO publishing $dest $dest_nested_catalog
   
   currdir=$(pwd)
   cd
   time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish+lhapdf.log
   status=$?
   cd $currdir
   if [ $status -eq 0 ] ; then
      printf "$(basename $0) cvmfs_server_publish OK \n$(cat $HOME/logs/cvmfs_server+publish+lhapdf.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish for $dest OK" $notifytowhom
      begin_transaction=0
      cp $THELOG $HOME/logs/cron_download_lhapdf+${dest_nested_catalog}.log
   else
      echo ERROR failed cvmfs_server publish
      printf "$(basename $0) cvmfs_server publish failed\n$(cat $HOME/logs/cvmfs_server+publish+lhapdf.log | sed 's#%#%%#g')\n" | mail -s "$(basename $0) cvmfs_server publish failed" $notifytowhom
      ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
      exit 1
   fi
   #else
   #   exit 1
   #fi
   #echo INFO checking ${lhapdf_top}/${dest}/
   #ls -al ${lhapdf_top}/${dest}/
   echo INFO done with $relv
done
if [ $begin_transaction -eq 1 ] ; then
   #printf "$(basename $0) cvmfs_server ending transaction\n" | mail -s "$(basename $0) cvmfs_server end of transaction" $notifytowhom
   ( cd ; cvmfs_server abort -f ; ) ; # cvmfs_server abort -f
else
   printf "$(basename $0) begin_transaction is 0\n" | mail -s "$(basename $0) begin_transaction 0" $notifytowhom
fi
exit 0



function unit_test () {
  lhapdfweb=http://www.hepforge.org/archive/lhapdf
  dest=pdfsets/6.1
  lhapdf_top=$HOME/lhapdf #$VO_CMS_SW_DIR/lhapdf dest_nested_catalog CVMFS
  dest_nested_catalog=pdfsets/6.1.c
  ntry=5
  files=$(wget -q --no-check-certificate -O- ${lhapdfweb}/$dest | grep "pdfsets.index\|tar.gz" | sed 's#href="#|#g' | cut -d\| -f2 | cut -d\" -f1)
   i=0
   for f in $files ; do
      i=$(expr $i + 1)
      ( [ -d $lhapdf_top/$dest_nested_catalog ] || { echo INFO creating $lhapdf_top/$dest_nested_catalog ; mkdir -p $lhapdf_top/$dest_nested_catalog ; } ;
        j=0
        while [ $j -lt $ntry ] ; do
           echo INFO "[ $i ] Trial=$j Downloading $f"
           wget -q --no-check-certificate -O $lhapdf_top/${dest_nested_catalog}/$f  ${lhapdfweb}/$dest/$f
           status=$?
           [ $status -eq 0 ] && break
           j=$(expr $j + 1)
        done
        #cd $lhapdf_top/${dest_nested_catalog} # new 22JUL2015 0.2.4
        echo INFO "[ $i ] Status $status"
        /usr/bin/file $lhapdf_top/${dest_nested_catalog}/$f | grep -q "gzip compressed data"
        if [ $? -eq 0 ] ; then
           cd $lhapdf_top/$dest_nested_catalog
           echo INFO "[ $i ] Unpacking $f"
           cd $lhapdf_top/${dest_nested_catalog}
           #tar xzf $f
           status=$(expr $status + $?)
           # DELETE tarball
           rm -f $lhapdf_top/${dest_nested_catalog}/$f
           cd -
        else
           echo INFO "[ $i ] $f is not a gzip compressed data"
           #status=$(expr $status + 1)
        fi
        echo INFO "[ $i ] Status $status"
        exit $status        
      )

      if [ $? -ne 0 ] ; then
         echo ERROR $f
         return 1
      fi

   done
   return 0
} 
