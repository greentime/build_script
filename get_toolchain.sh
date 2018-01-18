#!/bin/bash

work_folder=`pwd`
src_folder="$work_folder/src_pkg"
cd $work_folder/toolchain
wget https://github.com/greentime/prebuilt-nds32-toolchain/releases/download/20180118/nds32le-linux-glibc-v3.zip
unzip nds32le-linux-glibc-v3.zip
cd -