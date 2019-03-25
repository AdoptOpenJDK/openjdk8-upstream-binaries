#!/bin/bash
set -e

UPDATE=212
BUILD=b01
NAME="openjdk-8u${UPDATE}-${BUILD}"
NAME_SUFFIX="ea-linux-x86_64"
SOURCE_NAME="${NAME}-sources"

build() {
  set -x
  rm -rf build

  # Add patch to be able to build on EL 6
  wget https://bugs.openjdk.java.net/secure/attachment/81610/JDK-8219879.export.patch
  patch -p1 < JDK-8219879.export.patch

  bash common/autoconf/autogen.sh

  # Create a source tarball archive corresponding to the
  # binary build
  tar -c -z -f ../$SOURCE_NAME.tar.gz --exclude-vcs --exclude='**.patch*' --exclude='overall-build.log' .

  for debug in release slowdebug; do
    bash configure \
       --with-boot-jdk="/usr/lib/jvm/java-1.7.0-openjdk.x86_64" \
       --with-debug-level="$debug" \
       --with-conf-name="$debug" \
       --enable-unlimited-crypto \
       --with-milestone="fcs" \
       --with-native-debug-symbols=external \
       --with-cacerts-file=/etc/pki/java/cacerts \
       --with-update-version=$UPDATE \
       --with-build-number=$BUILD
    target="bootcycle-images"
    if [ "${debug}_" == "slowdebug_" ]; then
      target="images"
    fi
    make LOG_LEVEL=debug CONF=$debug $target
    # Package it up
    pushd build/$debug/images
      if [ "${debug}_" == "slowdebug_" ]; then
        NAME="$NAME-$debug"
      fi
      mv j2sdk-image $NAME
      cp src.zip $NAME
      tar -c -f $NAME-$NAME_SUFFIX.tar $NAME --exclude='**.debuginfo'
      gzip $NAME-$NAME_SUFFIX.tar
      tar -c -f $NAME-$NAME_SUFFIX-debuginfo.tar $(find ${NAME}/ -name \*.debuginfo)
      gzip $NAME-$NAME_SUFFIX-debuginfo.tar
      rm $NAME/src.zip
      mv $NAME j2sdk-image
    popd
  done
  mv ../$SOURCE_NAME.tar.gz build/
  set +x
}

build 2>&1 | tee overall-build.log

ALL_ARTEFACTS="$NAME-all-artefacts.tar"
tar -c -f $ALL_ARTEFACTS $(find build -name \*.tar.gz) overall-build.log
gzip $ALL_ARTEFACTS
ls -lh *.tar.gz
