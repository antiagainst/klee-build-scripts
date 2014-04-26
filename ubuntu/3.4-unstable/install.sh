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

CodeName=$(lsb_release --codename --short)
LLVMVersion="3.4"

LLVMKeyUri="http://llvm.org/apt/llvm-snapshot.gpg.key"
LLVMDeb="deb http://llvm.org/apt/${CodeName}/ llvm-toolchain-${CodeName}-${LLVMVersion} main"

Depends="git cmake bison flex libboost-program-options-dev libboost-system-dev libncurses5-dev libcap-dev g++ libgtest-dev"
Packages="llvm-${LLVMVersion}-tools clang-${LLVMVersion}"

add_llvm_repo() {
    (wget -O - ${LLVMKeyUri} | sudo apt-key add -) &> /dev/null
    sudo add-apt-repository --enable-source "${LLVMDeb}"
}

install_packages() {
    sudo apt-get update &> /dev/null
    yes | sudo apt-get install ${Depends} ${Packages} &> /dev/null
}

echo "adding llvm repo..."
add_llvm_repo    && success || failed
echo "installing dependencies..."
install_packages && success || failed

# build stp, klee-uclibc, and klee
# --------------------------------

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
    ln -sf $(which llvm-config-${LLVMVersion}) ${BuildDir}/llvm-config
    #export PATH=${BuildDir}:$PATH

    # libgtest-dev only installs header and source files
    # build the library if we have not do this earlier
    if [[ ! -e "/usr/lib/libgtest.a" ]]; then
        build_gtest
    fi
}

build_stp() {
    git_clone_or_update ${StpRepo} ${BuildDir}/stp
    cd ${BuildDir}/stp
    [[ ! -d "build" ]] && mkdir build
    cd build
    cmake ../ || return 1
    make -j${NumJobs} || return 1
    cd ${Pwd}
}

build_klee_uclibc() {
    git_clone_or_update ${KleeUClibcRepo} ${BuildDir}/klee-uclibc "--branch=${KleeUClibcBranch} --depth=1"
    cd ${BuildDir}/klee-uclibc
    PATH=${BuildDir}:$PATH ./configure --make-llvm-lib || return 1
    make -j${NumJobs} || return 1
    cd ${Pwd}
}

build_klee() {
    git_clone_or_update ${KleeRepo} ${BuildDir}/klee
    cd ${BuildDir}/klee
    PATH=${BuildDir}:$PATH ./configure \
        --with-stp=${BuildDir}/stp/build \
        --with-uclibc=${BuildDir}/klee-uclibc \
        --enable-posix-runtime \
        --prefix=${Prefix} || return 1
    make -j${NumJobs} ENABLE_OPTIMIZED=1 || return 1
    cd ${Pwd}
}

prepare
echo "building stp..."
build_stp         && success || failed
echo "building klee-uclibc..."
build_klee_uclibc && success || failed
echo "building klee..."
build_klee        && success || failed

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

# install
# -------

install_klee() {
    cd ${BuildDir}/klee
    make install
    cd ${Pwd}
}

install_klee && success || failed

# vim:set ts=4 sw=4 et:
