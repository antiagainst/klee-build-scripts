PKGBUILD for KLEE (Based on LLVM 3.3)
=====================================

Use this PKGBUILD to build LLVM (3.3), Clang (3.3), and KLEE on Archlinux.

#### Prerequisites

* Archlinux.
* package group `base-devel` installed.

#### Steps

1. Copy the `PKGBUILD` file to your build directory.
3. Enter that directory, `makepkg`, and wait for the building. Since we are building LLVM,
   Clang, and KLEE, this could take a long time.
4. When successful, A package named `klee-unstable-*.pkg.tar.xz` will be genenerated.
5. You can install it using `pacman -U klee-unstable-*.pkg.tar.xz`.

#### Notes

* `pacman` will install the generated `klee-unstable` package to `/usr/local`. You may
  want to change the `_prefix` variable in `PKGBUILD` to where you want to install KLEE.
* This PKGBUILD specifies `clang` as one of the `makedepends`. A `clang` package installed
  directly from the official repository is used to build LLVM, Clang, and klee-uclibc,
  etc. So after installing the `klee-unstable` package, two `clang`s exist. You may want
  to tune your `PATH` to use the correct one.
