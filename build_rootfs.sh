#!/bin/bash

work_folder=`pwd`
src_folder="$work_folder/src_pkg"
toolchain_folder="$work_folder/toolchain/nds32le-linux-glibc-v3"

setup ()
{
	# check toolchain
	[ ! -f $toolchain_folder/bin/nds32le-linux-gcc ] && \
   	echo "No toolcahin is existed. please execute build_toolchain.sh before build_rootfs.sh" \
   	&& exit 1

	# check rootfs source code
	[ -d rootfs ] ||\
	git clone https://github.com/andestech/rootfs.git -b nds32
	[ $? != 0 ] && echo "git clone fail" && exit 1
	[ -d $src_folder ] || mkdir -p $src_folder


	#check busybox source code
	cd $src_folder
	[ -d $src_folder/busybox ] ||\
	git clone https://github.com/andestech/busybox.git -b nds32_1_20_2
}

build_busybox ()
{
	cd $src_folder/busybox
	[ -f busybox ] ||\
	export CROSS_COMPILE=nds32le-linux-; \
	export PATH="$toolchain_folder"/bin:$PATH; \
	sh build_busybox.sh -EL


}
install_rootfs ()
{
	#install busybox
	cd $src_folder/busybox
	export CROSS_COMPILE=nds32le-linux-; \
	export PATH="$toolchain_folder"/bin:$PATH; \
	make CONFIG_PREFIX=$work_folder/rootfs/disk install

	cd $work_folder
	#copy library
	cp -ar $toolchain_folder/nds32le-linux/sysroot/lib \
		$work_folder/rootfs/disk/
	
	cp -ar $toolchain_folder/nds32le-linux/sysroot/usr/lib \
		$work_folder/rootfs/disk/usr
	cd $work_folder
}

setup
build_busybox
install_rootfs
