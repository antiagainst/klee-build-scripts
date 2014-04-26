Building script for KLEE (Based on LLVM 3.4)
============================================

Use this bash script to build KLEE on Ubuntu.

#### Prerequisites

* Ubuntu.
  * tested on newly installed 14.04

#### Versions

* LLVM: 3.4 (from [LLVM Ubuntu nightly packages](http://llvm.org/apt/))
* Clang: 3.4 (from [LLVM Ubuntu nightly packages](http://llvm.org/apt/))
* stp: latest commit in git repo
* klee-uclibc: branch `klee_0_9_29` in git repo
* KLEE: latest commit in git repo

#### Steps

1. `./install.sh`

#### Notes

* This script handles the common case; it may fail for some Ubuntu configurations.
* `Prefix` in the script controls where to install those compiled KLEE tools.
