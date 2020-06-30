#!/bin/bash
set -e

UPDATE=262
BUILD=b09
NAME="openjdk-8u${UPDATE}-${BUILD}"
JRE_NAME="${NAME}-jre"
TARBALL_BASE_NAME="OpenJDK8U"
EA_SUFFIX="_ea"
PLATFORM="x64_linux"
TARBALL_VERSION="8u${UPDATE}${BUILD}${EA_SUFFIX}"
PLATFORM_VERSION="${PLATFORM}_${TARBALL_VERSION}"
TARBALL_NAME="${TARBALL_BASE_NAME}-jdk_${PLATFORM_VERSION}"
TARBALL_NAME_JRE="${TARBALL_BASE_NAME}-jre_${PLATFORM_VERSION}"
TARBALL_NAME_JFR="${TARBALL_BASE_NAME}-jdk-jfr_${PLATFORM_VERSION}"
TARBALL_NAME_JFR_JRE="${TARBALL_BASE_NAME}-jre-jfr_${PLATFORM_VERSION}"
SOURCE_NAME="${TARBALL_BASE_NAME}-sources_${TARBALL_VERSION}"

build() {
  set -x
  # On some systems the per user process limit is set too low
  # by default (e.g. 1024). This may make the build fail on
  # systems with many cores (e.g. 64). Raise the limit to 1/2
  # of the maximum amount of threads allowed by the kernel.
  if [ -e /proc/sys/kernel/threads-max ]; then
    ulimit -u $(( $(cat /proc/sys/kernel/threads-max) / 2))
  fi

  rm -rf build

  # Add patch to be able to build on EL 6
  wget https://bugs.openjdk.java.net/secure/attachment/81610/JDK-8219879.export.patch
  patch -p1 < JDK-8219879.export.patch

  bash common/autoconf/autogen.sh

  # Create a source tarball archive corresponding to the
  # binary build
  tar -c -z -f ../${SOURCE_NAME}.tar.gz --transform "s|^|${NAME}-sources/|" --exclude-vcs --exclude='**.patch*' --exclude='overall-build.log' .

  MILESTONE="fcs"
  if [ "${EA_SUFFIX}_" != "_" ]; then
    MILESTONE="ea"
  fi

  for debug in release release-jfr slowdebug; do
    if [ "$debug" == "release-jfr" ]; then
       flag="--enable-jfr"
       dbg_level="release"
    else
       flag=""
       dbg_level="$debug"
    fi
    bash configure \
       --with-boot-jdk="/usr/lib/jvm/java-1.7.0-openjdk.x86_64" \
       "\$flag" \
       --with-debug-level="$dbg_level" \
       --with-conf-name="$debug" \
       --enable-unlimited-crypto \
       --with-milestone="$MILESTONE" \
       --with-native-debug-symbols=external \
       --with-update-version=$UPDATE \
       --with-build-number=$BUILD
    target="bootcycle-images"
    if [ "${debug}_" == "slowdebug_" ]; then
      target="images"
    fi
    make LOG_LEVEL=debug CONF=$debug $target
    archive_name="$TARBALL_NAME"
    jre_archive_name="$TARBALL_NAME_JRE"
    if [ "${debug}_" == "release-jfr_" ]; then
      archive_name="$TARBALL_NAME_JFR"
      jre_archive_name="$TARBALL_NAME_JFR_JRE"
    fi
    # Package it up
    pushd build/$debug/images
      if [ "${debug}_" == "slowdebug_" ]; then
        NAME="$NAME-$debug"
        TARBALL_NAME="$TARBALL_NAME-$debug"
      fi
      # JDK package
      mv j2sdk-image $NAME
      cp src.zip $NAME
      tar -c -f ${archive_name}.tar --exclude='**.debuginfo' $NAME
      gzip ${archive_name}.tar
      tar -c -f ${archive_name}-debuginfo.tar $(find ${NAME}/ -name \*.debuginfo)
      gzip ${archive_name}-debuginfo.tar
      rm $NAME/src.zip
      mv $NAME j2sdk-image
      # JRE package (release only)
      if [ "${debug}_" == "release_" || "${debug}_" == "release-jfr_"]; then
        mv j2re-image $JRE_NAME
        tar -c -f ${jre_archive_name}.tar --exclude='**.debuginfo' $JRE_NAME
        gzip ${jre_archive_name}.tar
        tar -c -f ${jre_archive_name}-debuginfo.tar $(find ${JRE_NAME}/ -name \*.debuginfo)
        gzip ${jre_archive_name}-debuginfo.tar
        mv $JRE_NAME j2re-image
      fi
    popd
  done
  mv ../${SOURCE_NAME}.tar.gz build/
  set +x
}

build 2>&1 | tee overall-build.log

ALL_ARTEFACTS="$NAME-all-artefacts.tar"
tar -c -f $ALL_ARTEFACTS $(find build -name \*.tar.gz) overall-build.log
gzip $ALL_ARTEFACTS
ls -lh *.tar.gz
