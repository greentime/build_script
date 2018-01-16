#!/bin/bash
work_folder=`pwd`

src_folder="$work_folder/src_pkg"
toolchain_folder="$work_folder/toolchain/nds32le-linux-glibc-v3"
rootfs_folder="$work_folder/rootfs/disk"

export PATH="$toolchain_folder"/bin:$PATH

build_kernel ()
{
	cd $src_folder/linux
	ARCH=nds32 CROSS_COMPILE=nds32le-linux- make defconfig
	sed -ir "s#CONFIG_INITRAMFS_SOURCE=\"\"#CONFIG_INITRAMFS_SOURCE=\"$rootfs_folder ${rootfs_folder}/dev/initramfs.devnodes\"#" .config;
	ARCH=nds32 CROSS_COMPILE=nds32le-linux- make olddefconfig
	ARCH=nds32 CROSS_COMPILE=nds32le-linux- make -j8
}
build_kernel
