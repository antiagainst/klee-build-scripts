#!/bin/bash

# utility functions
# -----------------

success() {
    printf "%025s\n" "[success]"
}

failed() {
    printf "%025s\n" "[failed]"
    exit 1
}

# $1: remote repo uri
# $2: local directory
# $3: additional arguments for git
git_clone_or_update() {
    if [[ -d "$2" && -d "$2/.git" ]]; then
        cd "$2"
        git pull
        cd -
    else
        git clone $3 $1 $2
    fi
}

# add llvm repo and install dependencies
# --------------------------------------

Depends="git cmake bison flex libboost-program-options-dev libboost-system-dev libncurses5-dev libcap-dev g++ libgtest-dev gcc-multilib"
Packages="llvm clang"

install_packages() {
    sudo apt-get update #&> /dev/null
    echo "Y" | sudo apt-get install ${Depends} ${Packages} #&> /dev/null
}

echo "installing dependencies..."
install_packages && success || failed

# build llvm, clang, stp, klee-uclibc, and klee
# ---------------------------------------------

LLVMDL="http://llvm.org/releases/2.9"
LLVMTarball="http://llvm.org/releases/2.9/llvm-2.9.tgz"
ClangTarball="http://llvm.org/releases/2.9/clang-2.9.tgz"
LLVMGCCTarball="llvm-gcc4.2-2.9-x86_64-linux.tar.bz2"
StpRepo="https://github.com/stp/stp.git"
KleeUClibcRepo="https://github.com/klee/klee-uclibc.git"
KleeRepo="https://github.com/klee/klee.git"

KleeUClibcBranch="klee_0_9_29"

BuildDir=$(pwd)
Pwd=$(pwd)
NumJobs=$(grep -c processor /proc/cpuinfo)

# XXX change to where you want to install klee
Prefix="${HOME}/klee/install"

build_gtest() {
    cd /tmp
    [[ -d "gtest-build" ]] && rm -rf gtest-build
    mkdir gtest-build && cd gtest-build
    cmake -DCMAKE_BUILD_TYPE=RELEASE /usr/src/gtest/
    make -j${NumJobs}
    sudo mv libg* /usr/lib/
    cd ${Pwd}
}

prepare() {
    # libgtest-dev only installs header and source files
    # build the library if we have not done this earlier
    if [[ ! -e "/usr/lib/libgtest.a" ]]; then
        build_gtest
    fi
    # without the following symlink, clang (2.9) cannot find crt1.o and crti.o
    sudo ln -sf /usr/lib/x86_64-linux-gnu /usr/lib64

    # https://bugs.launchpad.net/ubuntu/+source/llvm-defaults/+bug/1242300
    #sudo ln -sf /usr/lib/llvm-3.2/lib/clang/3.2/include /usr/lib/clang/3.2/include

    # install llvm-gcc binaries
    [[ -e ${LLVMGCCTarball} ]] || wget ${LLVMDL}/${LLVMGCCTarball}
    mkdir -p ${Prefix}
    [[ -e ${Prefix}/bin/llvm-gcc ]] || tar -xjf ${LLVMGCCTarball} -C ${Prefix} --strip-components=1
}

build_llvm_clang() {
    cd ${BuildDir}
    if [ ! -d "llvm-2.9" ]; then
        wget -O - ${LLVMTarball}  | tar xzf -
        patch -p0 < ${Pwd}/patches/unistd-llvm-2.9-jit.patch
    fi
    if [ ! -d "llvm-2.9/tools/clang" ]; then
        wget -O - ${ClangTarball} | tar xzf -
        patch -p0 < ${Pwd}/patches/clang-2.9-gcc.patch
        mv clang-2.9 llvm-2.9/tools/clang
    fi
    cd llvm-2.9
    ./configure \
        --enable-optimized \
        --enable-assertions \
        --prefix=${Prefix} || return 1
    make -j${NumJobs} || return 1
    cd ${Pwd}
}

install_llvm_clang() {
    cd ${BuildDir}/llvm-2.9
    make install
    cd ${Pwd}
}

build_stp() {
    git_clone_or_update ${StpRepo} ${BuildDir}/stp
    cd ${BuildDir}/stp
    [[ ! -d "build" ]] && mkdir build
    cd build
    cmake -DCMAKE_INSTALL_PREFIX:PATH=${Prefix} ../ || return 1
    make -j${NumJobs} || return 1
    cd ${Pwd}
}

install_stp() {
    cd ${BuildDir}/stp/build
    make install
    cd ${Pwd}
}

build_klee_uclibc() {
    git_clone_or_update ${KleeUClibcRepo} ${BuildDir}/klee-uclibc "--branch=${KleeUClibcBranch} --depth=1"
    cd ${BuildDir}/klee-uclibc
    ./configure \
        --with-llvm-config=${Prefix}/bin/llvm-config \
        --with-cc=${Prefix}/bin/llvm-gcc \
        --make-llvm-lib || return 1
        make -j${NumJobs} || return 1
    cd ${Pwd}
}

build_klee() {
    git_clone_or_update ${KleeRepo} ${BuildDir}/klee
    cd ${BuildDir}/klee
    ./configure \
        --with-llvm=${BuildDir}/llvm-2.9 \
        --with-stp=${BuildDir}/stp/build \
        --with-uclibc=${BuildDir}/klee-uclibc \
        --enable-posix-runtime \
        --prefix=${Prefix} || return 1
    make -j${NumJobs} ENABLE_OPTIMIZED=1 || return 1
    cd ${Pwd}
}

prepare
echo "building llvm and clang..."
build_llvm_clang   && success || failed
echo "installing llvm and clang..."
install_llvm_clang && success || failed
echo "building stp..."
build_stp          && success || failed
echo "installing stp..."
install_stp        && success || failed
echo "building klee-uclibc..."
build_klee_uclibc  && success || failed
echo "building klee..."
build_klee         && success || failed

# test
# ----

test_klee() {
    cd ${BuildDir}/klee
    make -k test || return 1
    make -k unittests || return 1
    cd ${Pwd}
}

echo "testing klee..."
#test_klee && success || failed

# install klee
# ------------

install_klee() {
    cd ${BuildDir}/klee
    make install
    cd ${Pwd}
}

install_klee       && success || failed

# vim:set ts=4 sw=4 et:
