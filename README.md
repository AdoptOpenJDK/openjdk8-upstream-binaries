#OpenJDK Upstream Binaries (JDK 8u)

Not to be confused with the official AdoptOpenJDK binaries [openjdk8-binaries](https://github.com/AdoptOpenJDK/openjdk8-binaries)

_openjdk8-upstream-binaries_ are pure unaltered builds from the OpenJDK mercurial jdk8u code stream which have been built by Red Hat on behalf of the OpenJDK community jdk8u updates project.

## Build Scripts

This repository also contains [build scripts](install-rhel6-deps-build-openjdk8.sh) which were used to produce binaries released under this repository. See [usage](README.md#Usage) for more information.

### Usage

On your newly commissioned RHEL 6 machine, you can run these steps to produce a build:

    $ wget -O jdk8u-master.tar.gz "https://github.com/AdoptOpenJDK/openjdk8-upstream-binaries/archive/master.tar.gz"
    $ tar -xf jdk8u-master.tar.gz
    $ cd jdk8u-master
    $ bash install-rhel6-deps-build-openjdk8.sh

This will produce a file in `/home/openjdk` called `openjdk-*-all-artefacts.tar.gz`,
which is about 441 MB in size, containing:

 * The JDK 8 build log
 * The JDK 8 image (including src.zip), without debuginfo
 * The JKD 8 debuginfo files for the JDK 8 image (overlay)
 * The JDK 8 image in slowdebug version
 * The JDK 8 debuginfo files for the slowdebug version
 * The JDK 8 source tarball

Example:

    jdk8u/
    jdk8u/overall-build.log
    jdk8u/build/release/images/openjdk-8u212-b00-debuginfo.tar.gz
    jdk8u/build/release/images/openjdk-8u212-b00.tar.gz
    jdk8u/build/openjdk-8u212-b00-sources.tar.gz
    jdk8u/build/slowdebug/images/openjdk-8u212-b00-slowdebug.tar.gz
    jdk8u/build/slowdebug/images/openjdk-8u212-b00-slowdebug-debuginfo.tar.gz


###Only Build OpenJDK 8 (without Build Requirements)

If you already have the build requirements for building OpenJDK 8 installed, you can
use a simpler build script to build OpenJDK 8:

    $ wget -O jdk8u-master.tar.gz "https://github.com/AdoptOpenJDK/openjdk8-upstream-binaries/archive/master.tar.gz"
    $ tar -xf jdk8u-master.tar.gz
    $ cd jdk8u-master
    $ bash build-openjdk8.sh
