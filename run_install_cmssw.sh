#!/bin/bash
#
# Versions
# 1.8.7

source $HOME/functions-cms-cvmfs-mgmt
version=1.8.7
what=$(basename $0)

# Download releases.map once
wget --no-check-certificate -q -O $releases_map_local  "${releases_map}"
if [ $? -ne 0 ] ; then
   printf "$(basename $what) $(hostname -f) failed to download ${releases_map}\n" | mail -s "ERROR $(basename $what) $(hostname -f) failed to download releases_map" $notifytowhom
   exit 1
fi

# release.map
archs=$(list_announced_cmssw_archs | grep -v "$archs_excluded")
narchs=$(echo $archs | wc -w)

echo INFO archs available
for a in $archs ; do echo $a ; done

i=0
nslc=$(echo $VO_CMS_SW_DIR/slc* | wc -w)
for thedir in $VO_CMS_SW_DIR/slc* ; do
	[ "x$thedir" == "x$VO_CMS_SW_DIR/slc*" ] && break
	[ -d $thedir ] || continue
	i=$(expr $i + 1)
	ls -al $thedir/.cvmfscatalog 2>/dev/null 1>/dev/null ;
	if [ $? -eq 0 ] ; then
	    echo INFO "[ $i / $nslc ]" $thedir/.cvmfscatalog exists
	else
	    printf "$(basename $what) Starting cvmfs_server transaction for cvmfscatalog\n" | mail -s "cvmfs_server transaction started" $notifytowhom
	    cvmfs_server transaction
	    status=$?
	    whatwhat="$(basename $what) $thedir/.cvmfscatalog"
	    cvmfs_server_transaction_check $status $whatwhat
	    if [ $? -eq 0 ] ; then
		echo INFO transaction OK for $whatwhat
	    else
		printf "cvmfs_server_transaction_check Failed for $whatwhat\n" | mail -s "ERROR: cvmfs_server_transaction_check Failed" $notifytowhom
		exit 1
	    fi
	    echo INFO "[ $i / $nslc ]" creating $thedir/.cvmfscatalog
	    touch $thedir/.cvmfscatalog
	    
	    currdir=$(pwd)
	    cd
	    time cvmfs_server publish 2>&1 |  tee $HOME/logs/cvmfs_server+publish.log
	    cd $currdir
	    printf "$thedir/.cvmfscatalog published  \n$(cat $HOME/logs/cvmfs_server+publish.log | sed 's#%#%%#g')\n" | mail -s "cvmfs_server publish Done" $notifytowhom
	fi
done

# Additional archs
archs="$archs cc8_amd64_gcc8"
i=0
j=$(expr $j + 1)
echo INFO "[$j]" ARCHS Available: $archs
for arch in $archs ; do
        #[ "x$jenkins_cmssw" == "xon" ] && break
	echo "$arch" | grep -q amd64_gcc
	[ $? -eq 0 ] || continue
	echo "$arch" | grep -q slc5_amd64_gcc
	[ $? -eq 0 ] && continue

	i=$(expr $i + 1)
	echo "     INFO [ $i / $narchs ]" arch=$arch
        # Do a bootstrap if necessary
	j=$(expr $j + 1)
	echo INFO "[$j]" do a bootstrap if necessary
	if [ $(ls -al $VO_CMS_SW_DIR/${arch}/external/rpm/*/etc/profile.d/init.sh 2>/dev/null 1>/dev/null ; echo $? ; ) -eq 0 ] ; then
	    echo INFO "[$j]" arch $arch seems to be already bootstrapped
	else
	    if [ "x$jenkins_cmssw" == "xon" ] ; then
		printf "$(basename $what) $(hostname -f) Bootstrapping necessary for $arch\nBut Jenkins is on\n" | mail -s "$(basename $what) $(hostname -f) Bootstrapping necessary for $arch" $notifytowhom
	    else
		echo INFO "[$j]" bootstrapping bootstrap_arch $arch
		bootstrap_arch $arch
	    fi
	    if [ $? -eq 0 ] ; then
		printf "$(basename $what) $(hostname -f) Success: bootstrap_arch $arch \n$(cat $VO_CMS_SW_DIR/bootstrap_${arch}.log | sed 's#%#%%#g')\n" | mail -s "$(basename $what) $(hostname -f) Success: bootstrap_arch $arch " $notifytowhom      
	    else
		echo INFO checking if it is an slc7
		echo $arch | grep -q slc7
		if [ $? -eq 0 ] ; then
		    bootstrap_arch_slc7 $arch > $workdir/logs/bootstrap_arch_slc7_${arch}.log 2>&1
		    if [ $? -eq 0 ] ; then
			printf "$(basename $what) $(hostname -f) Success: bootstrap_arch_tarball $arch \n$(cat $VO_CMS_SW_DIR/bootstrap_${arch}.log | sed 's#%#%%#g')\n" | mail -s "$(basename $what) $(hostname -f) Success: bootstrap_arch_tarball $arch " $notifytowhom
		    else
			printf "$(basename $what) $(hostname -f) failed: bootstrap_arch $arch \n$(cat $workdir/logs/bootstrap_arch_slc7_${arch}.log | sed 's#%#%%#g')\n" | mail -s "ERROR $(basename $what) $(hostname -f) bootstrap_arch $arch failed " $notifytowhom
			continue
		    fi
		else
		    echo INFO checking if it is an cc8_
		    echo $arch | grep -q cc8_
		    if [ $? -eq 0 ] ; then
			bootstrap_arch_nn $arch > $workdir/logs/bootstrap_arch_nn_${arch}.log 2>&1
			if [ $? -eq 0 ] ; then
			    printf "$(basename $what) $(hostname -f) Success: bootstrap_arch_nn $arch \n$(cat $workdir/logs/bootstrap_arch_nn_${arch}.log | sed 's#%#%%#g')\n" | mail -s "$(basename $what) $(hostname -f) Success: bootstrap_arch_nn $arch " $notifytowhom #-a $workdir/logs/bootstrap_arch_nn_${arch}.log
			else
			    printf "$(basename $what) $(hostname -f) failed: bootstrap_arch_nn $arch  \n$(cat $workdir/logs/bootstrap_arch_nn_${arch}.log | sed 's#%#%%#g')\n" | mail -s "ERROR $(basename $what) $(hostname -f) bootstrap_arch_nn $arch failed " $notifytowhom #-a $workdir/logs/bootstrap_arch_nn_${arch}.log
			    continue
			fi
		    fi
		fi
	    fi

            # rpmdb needs to be small/local on the cvmfs server, create a softlink that is backed up
	    echo INFO rpmdb needs to be small/local on the cvmfs server, create a softlink that is backed up
            ( cd $VO_CMS_SW_DIR/${arch}/var/lib
		if [ -L rpm ] ; then
		    echo INFO soft link for rpm exists
		    ls -al rpm
		else
		    echo Warning creating the needed soft-link
		    cp -pR rpm rpm.$(date +%d%b%Y | tr '[a-z]' '[A-Z]')
		    cp -pR rpm ${rpmdb_local_dir}/rpm_${arch}
		    rm -rf rpm
		    ln -s  ${rpmdb_local_dir}/rpm_${arch} rpm
		fi
            )
     
	fi
	j=$(expr $j + 1)
	echo INFO "[$j]" install cmssw if necessary for $arch
        # release.map
	cmssws=$(list_announced_arch_cmssws $arch | grep CMSSW_)
	if [ $? -ne 0 ] ; then
	    printf "ERROR: list_announced_arch_cmssws $arch failed\n" | mail -s "ERROR: list_announced_arch_cmssws $arch failed" $notifytowhom
	    continue
	fi
	if [ "x$arch" == "xcc8_amd64_gcc8" ] ; then
	    :
	fi
	k=0
	ncmssws=$(echo $cmssws | wc -w)
	echo DEBUG WILL DO arch=$arch and
	for cmssw in $cmssws ; do
	    echo $cmssw
	done

	for cmssw in $cmssws ; do
            # skip some troublesome releases
	    echo $arch | grep -q slc6_amd64_gcc600
	    if [ $? -eq 0 ] ; then
		echo $cmssw | grep -q CMSSW_8_1_0_pre[4-8]
		[ $? -eq 0 ] && continue
	    fi
	    echo $cmssw | grep -q CMSSW_10_0_X
	    [ $? -eq 0 ] && continue
	    echo $cmssw | grep -q [0-9]_X$
	    [ $? -eq 0 ] && { echo Warning $cmssw is excluded so continue ; continue ; } ;

	    grep -q "$cmssw $arch" $updated_list # if it is not in the updated_list, it should be reinstall, e.g., power outage, $db
            [ $? -eq 0 ] && continue

	    for cmssw_e in $cmssws_excluded ; do
		echo "+"${cmssw_e}"+"
	    done | grep -q "+"${cmssw}"+"
	    if [ $? -eq 0 ] ; then
		echo Warning ${cmssw} is in $cmssws_excluded Skipping it
		continue
	    fi

            # 4 install cmssw
	    k=$(expr $k + 1)
	    echo "INFO [ $k / $ncmssws ]" cmssw=$cmssw arch=$arch
	    install_cmssw_function=install_cmssw
	    echo "$arch" | grep -q "slc7_"
	    if [ $? -eq 0 ] ; then
		install_cmssw_function=install_cmssw_non_native
		docker images 2>/dev/null | grep $(echo $DOCKER_TAG | cut -d: -f1) | grep -q $(echo $DOCKER_TAG | cut -d: -f2)
		if [ $? -eq 0 ] ; then
		    install_cmssw_function=docker_install_nn_cmssw
		    printf "$(basename $what) INFO: using docker_install_nn_cmssw to install $cmssw  $arch\n" | mail -s "$(basename $what) INFO: using docker_install_nn_cmssw" $notifytowhom
		else
		    printf "$(basename $what) INFO: it seems docker is installed but $DOCKER_TAG not found\n$(docker images | sed 's#%#%%#g')\n" | mail -s "$(basename $what) INFO: $DOCKER_TAG not found" $notifytowhom
		fi
	    else
		echo "$arch" | grep -q ${which_slc}_
		if [ $? -ne 0 ] ; then
		    echo "$arch" | grep -q "slc6_"
		    if [ $(echo "$arch" | grep -q "slc6_" ; echo $?) -eq 0 ] ; then
			install_cmssw_function=docker_install_nn_cmssw
		    elif [ $(echo "$arch" | grep -q "slc8_" ; echo $?) -eq 0 ] ; then
			install_cmssw_function=docker_install_nn_cmssw
		    elif [ $(echo "$arch" | grep -q "cc8_" ; echo $?) -eq 0 ] ; then
			install_cmssw_function=docker_install_nn_cmssw
		    else
			echo ERROR do not know how to install $cmssw $arch
			printf "$(basename $what) ERROR: do not know how to install $cmssw  $arch\n" | mail -s "$(basename $what) ERROR: FAILED do not know how to install $cmssw  $arc" $notifytowhom
			continue
		    fi
		fi
	    fi
	    if [ "x$jenkins_cmssw" == "xon" ] ; then
		printf "$(basename $what) $(hostname -f) Supposedly $install_cmssw_function $cmssw $arch necessary\nBut Jenkins is on\n" | mail -s "$(basename $what) $(hostname -f) Install needed $cmssw $arch" $notifytowhom
		continue
	    fi
	    echo INFO "$install_cmssw_function $cmssw $arch > $HOME/logs/${install_cmssw_function}+${cmssw}+${arch}.log"
	    $install_cmssw_function $cmssw $arch > $HOME/logs/${install_cmssw_function}+${cmssw}+${arch}.log 2>&1
	    status=$?
	    echo INFO status of install_cmssw_function $install_cmssw_function $cmssw $arch $status
	    if [ $status -ne 0 ] ; then
		continue
	    fi

	    add_nested_entry_to_cvmfsdirtab ${arch}
	    [ $? -eq 0 ] || printf "$(basename $what) ERROR: Failed to add the entry /${arch}/cms/$thecmssw to $VO_CMS_SW_DIR/.cvmfsdirtab\n" | mail -s "$(basename $what) ERROR: FAILED to add the nested CVMFS dir entry for $arch" $notifytowhom

	    j=$(expr $j + 1)
	    echo INFO "[$j]" publish the installed cmssw on cvmfs if necessary
	    publish_cmssw_cvmfs ${0}+${cmssw}+${arch}
	    if [ $? -eq 0 ] ; then
		echo "INFO [ $k / $ncmssws ]" cmssw=$cmssw arch=$arch published
		grep -q "$cmssw $arch" $updated_list
		if [ $? -ne 0 ] ; then
		    currdir_1=$(pwd)
		    cd
		    cvmfs_server transaction
		    status=$?
		    whatwhat="adding_$cmssw_$arch_to_updated_list"
		    cvmfs_server_transaction_check $status $whatwhat
		    if [ $? -eq 0 ] ; then
			echo INFO transaction OK for $whatwhat
		    fi
		    echo INFO adding $cmssw $arch to $updated_list
		    echo $cmssw $arch $(/bin/date +%s) $(/bin/date -u) >> $updated_list
		    printf "$(basename $what): $cmssw $arch added to $updated_list \n$(cat $updated_list)\n" | mail -s "$(basename $what): INFO $cmssw $arch added to $updated_list" $notifytowhom
		    publish_cmssw_cvmfs ${0}+${cmssw}+${arch}+$updated_list
		    cd $currdir_1
		fi
	    else
		printf "$(basename $what): cvmfs_server publish failed for $cmssw $arch \n$(cat $HOME/logs/cvmfs_server+publish+cmssw+install.log | sed 's#%#%%#g')\n" | mail -s "$(basename $what): cvmfs_server publish failed" $notifytowhom
	    fi
	done
done

exit 0
