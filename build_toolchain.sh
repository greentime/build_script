#!/bin/bash
work_folder=`pwd`

src_folder="$work_folder/src_pkg"
build_folder="$work_folder/build" 
toolchain_folder="$work_folder/toolchain/nds32le-linux-glibc-v3"
build_day=`date +%Y-%m-%d`

export PATH="$toolchain_folder"/bin:$PATH
export LD_LIBRARY_PATH=

src_clone ()
{
	[ -d $src_folder ] && rm -rf $src_folder
	mkdir $src_folder

	cd $src_folder
	git clone https://github.com/andestech/binutils.git \
					-b bsp-v4_1_0-branch-open binutils-2.24
	git clone https://github.com/andestech/gcc.git \
					-b nds32-6.3.0-open gcc-6.3.0
	git clone https://github.com/andestech/glibc.git \
					-b nds32-glibc-2.25 glibc-2.25
	git clone https://github.com/andestech/linux.git -b nds32-4.14-rc8-v7
	
	#Generate host-tool
	cd gcc-6.3.0
	sh ./contrib/download_prerequisites

	cd $work_folder
}

clean_build ()
{
	[ -d $toolchain_folder ] && rm -rf $toolchain_folder
	mkdir -p $toolchain_folder/nds32le-linux/sysroot/usr/include
	
	[ -d $build_folder ] && rm -rf $build_folder
	mkdir $build_folder
}
#----------
#binutils
#----------
build_binutils ()
{
	if [ ! -d "$src_folder"/binutils-2.24 ];then
	       echo "no binutils source code" 
	       exit 1
	fi
	mkdir -p "$build_folder"/binutils
	
	cd "$build_folder"/binutils
	
	"$src_folder"/binutils-2.24/configure \
	--prefix=$toolchain_folder \
	--target=nds32le-linux \
	--with-arch=v3 \
	--disable-werror \
	--disable-nls \
	--with-sysroot=$toolchain_folder/nds32le-linux/sysroot
	
	
	make -j8
	
	make install
	
	
	cd $work_folder
}
#----------
#bootstrap gcc
#----------
build_bootstrap_gcc ()
{
	if [ ! -d "$src_folder"/gcc-6.3.0 ];then
	       	echo "no gcc source code"
		exit 1
	fi
	mkdir -p "$build_folder"/gcc_1
	
	cd "$build_folder"/gcc_1
	
	
	
	"$src_folder"/gcc-6.3.0/configure \
	--target=nds32le-linux \
	--prefix=$toolchain_folder \
	--with-pkgversion="$build_day"_nds32le-linux-glibc \
	--disable-nls \
	--enable-languages=c,c++ \
	--with-arch=v3 \
	--with-cpu=n13 \
	--enable-default-relax=no \
	--enable-Os-default-ifc=no \
	--enable-Os-default-ex9=no \
	--with-nds32-lib=glibc \
	--disable-libsanitizer \
	--disable-werror \
	--disable-multilib \
	--enable-shared \
	--enable-tls \
	CFLAGS="-O2 -g" \
	CXXFLAGS="-O2 -g" \
	--enable-checking=release \
	LDFLAGS=--static \
	CFLAGS_FOR_TARGET="-O2 -g" \
	CXXFLAGS_FOR_TARGET="-O2 -g" \
	LDFLAGS_FOR_TARGET=
	
	if [ -d "/usr/lib/gcc/x86_64-linux-gnu/4.8" ];then
		cd /usr/lib/gcc/x86_64-linux-gnu/4.8
		sudo cp crtbeginT.o crtbeginT.orig.o
		sudo cp crtbeginS.o crtbeginT.o
		cd -
	fi
	CFLAGS="-O0 -g3" CXXFLAGS="-O0 -g3" \
	make -j8 all-gcc
	
	make install-gcc

	make configure-target-libgcc

	cd nds32le-linux/libgcc	
	make unwind.h
	make install-unwind_h

	if [ -d "/usr/lib/gcc/x86_64-linux-gnu/4.8" ];then
		cd /usr/lib/gcc/x86_64-linux-gnu/4.8
		sudo cp crtbeginT.orig.o crtbeginT.o
		sudo rm crtbeginT.orig.o
		cd -
	fi
	cd $work_folder
}
#---------
#kernel headers
#----------
build_kernel_header ()
{
	if [ ! -d "$src_folder"/linux ];then
	       echo "no linux source code" 
	       exit 1
	fi
	cd $src_folder/linux
	
	PATH=$toolchain_folder/bin:$PATH \
	CROSS_COMPILE=nds32le-linux- ARCH=nds32 make defconfig
	
	PATH=$toolchain_folder/bin:$PATH \
	CROSS_COMPILE=nds32le-linux- ARCH=nds32 make headers_check
	
	PATH=$toolchain_folder/bin:$PATH \
	CROSS_COMPILE=nds32le-linux- ARCH=nds32 make \
	INSTALL_HDR_PATH=$toolchain_folder/nds32le-linux/sysroot/usr \
	headers_install
	
	cd $work_folder
}
#----------
#glibc headers and startup files
#----------
build_glibc_headers ()
{
	if [ ! -d "$src_folder"/glibc-2.25 ];then
	       echo "no linux glibc code" 
	       exit 1
	fi
	mkdir -p "$build_folder"/glibc
	
	cd "$build_folder"/glibc
	PATH=$toolchain_folder/bin:$PATH \
	libc_cv_forced_unwind=yes \
	$src_folder/glibc-2.25/configure \
	--prefix=/usr \
	--build=$MACHTYPE \
	--host=nds32le-linux \
	--target=nds32le-linux \
	--enable-versioning \
	--enable-obsolete-rpc \
	--with-headers=$toolchain_folder/nds32le-linux/sysroot/usr/include
	
	
	PATH=$toolchain_folder/bin:$PATH \
	make install-bootstrap-headers=yes install-headers \
			install_root=$toolchain_folder/nds32le-linux/sysroot
	
	
	PATH=$toolchain_folder/bin:$PATH \
	make -j4 csu/subdir_lib

	mkdir -p $toolchain_folder/nds32le-linux/sysroot/usr/lib	
	install csu/crt1.o csu/crti.o csu/crtn.o \
			$toolchain_folder/nds32le-linux/sysroot/usr/lib
	
	PATH=$toolchain_folder/bin:$PATH \
	nds32le-linux-gcc -nostdlib -nostartfiles \
	-fPIC -shared \
	-x c \
	/dev/null \
	-o $toolchain_folder/nds32le-linux/sysroot/usr/lib/libc.so
	
	touch \
	$toolchain_folder/nds32le-linux/sysroot/usr/include/gnu/stubs.h
	
	cd $work_folder

}


#----------
#libgcc
#----------
build_libgcc ()
{
	if [ ! -d "$src_folder"/gcc-6.3.0 ];then
	       	echo "no gcc source code"
		exit 1
	fi
	mkdir -p "$build_folder"/gcc_2

	cd "$build_folder"/gcc_2
	"$src_folder"/gcc-6.3.0/configure \
	--target=nds32le-linux \
	--prefix="$toolchain_folder" \
	--with-pkgversion="$build_day"_nds32le-linux-glibc \
	--disable-nls \
	--enable-languages=c,c++ \
	--with-arch=v3 \
	--with-cpu=n13 \
	--enable-default-relax=no \
	--with-nds32-lib=glibc \
	--disable-libsanitizer \
	--disable-werror \
	--disable-multilib \
	--enable-shared \
	--enable-tls \
	--with-sysroot="$toolchain_folder"/nds32le-linux/sysroot \
	CFLAGS="-O2 -g" \
	CXXFLAGS="-O2 -g" \
	--enable-checking=release \
	LDFLAGS=--static \
	CFLAGS_FOR_TARGET="-O2 -g" \
	CXXFLAGS_FOR_TARGET="-O2 -g" \
	LDFLAGS_FOR_TARGET=

	PATH=$toolchain_folder/bin:$PATH \
	make -j8 all-target-libgcc
	
	PATH=$toolchain_folder/bin:$PATH \
	make install-target-libgcc
	
	cd $work_folder
}



#----------
#glibc
#----------
build_glibc ()
{
	if [ ! -d "$src_folder"/glibc-2.25 ];then
	       echo "no linux glibc code" 
	       exit 1
	fi
	cd "$build_folder"/glibc

	CFLAGS="-O0 -g3" CXXFLAGS="-O0 -g3" \
	CROSS_COMPILE=nds32le-linux- ARCH=nds32 PATH=$toolchain_folder/bin:$PATH \
	make -j8
	
	PATH=$toolchain_folder/bin:$PATH \
	make install install_root=$toolchain_folder/nds32le-linux/sysroot
		
	cd $work_folder
}

#----------
#final gcc
#----------
build_final_gcc ()
{
	if [ ! -d "$src_folder"/gcc-6.3.0 ];then
	       	echo "no gcc source code"
		exit 1
	fi
	mkdir -p "$build_folder"/final_gcc
	cd "$build_folder"/final_gcc

	PATH=$toolchain_folder/bin:$PATH \
	"$src_folder"/gcc-6.3.0/configure \
	--target=nds32le-linux \
	--prefix="$toolchain_folder" \
	--with-pkgversion="$build_day"_nds32le-linux-glibc-v3-4.x \
	--disable-nls \
	--enable-languages=c,c++ \
	--with-arch=v3 \
	--with-cpu=n13 \
	--enable-default-relax=no \
	--with-nds32-lib=glibc \
	--disable-libsanitizer \
	--disable-multilib \
	--enable-shared \
	--enable-tls \
	--with-sysroot="$toolchain_folder"/nds32le-linux/sysroot \
	CFLAGS="-O2 -g" \
	CXXFLAGS="-O2 -g" \
	--enable-checking=release \
	LDFLAGS=--static \
	CFLAGS_FOR_TARGET="-O2 -g" \
	CXXFLAGS_FOR_TARGET="-O2 -g" \
	LDFLAGS_FOR_TARGET=

	if [ -d "/usr/lib/gcc/x86_64-linux-gnu/4.8" ];then
		cd /usr/lib/gcc/x86_64-linux-gnu/4.8
		sudo cp crtbeginT.o crtbeginT.orig.o
		sudo cp crtbeginS.o crtbeginT.o
	fi
	PATH=$toolchain_folder/bin:$PATH \
	make -j8 SHARED=0 CFLAGS='-static -std=gnu99 -static-libgcc -static-libstdc++ -fPIC'

	PATH=$toolchain_folder/bin:$PATH \
	make install
	if [ -d "/usr/lib/gcc/x86_64-linux-gnu/4.8" ];then
		cd /usr/lib/gcc/x86_64-linux-gnu/4.8
		sudo cp crtbeginT.orig.o crtbeginT.o
		sudo rm crtbeginT.orig.o
	fi

	# Copy all shared library which is created by gcc to sysroot folder
	find "$toolchain_folder"/nds32le-linux/lib -name "*.so*" \
	   | xargs -i cp -ar {} "$toolchain_folder"/nds32le-linux/sysroot/lib
	
	cd $work_folder
}
src_clone
clean_build
build_binutils
build_bootstrap_gcc
build_kernel_header
build_glibc_headers
build_libgcc
build_glibc
build_final_gcc
