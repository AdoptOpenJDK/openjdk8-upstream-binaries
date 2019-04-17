#!/bin/bash
set -e

BRS_FILE=openjdk_build_deps.txt
BUILD_SCRIPT=build-openjdk8.sh

cat > $BRS_FILE <<EOF
autoconf
automake
alsa-lib-devel
binutils
cups-devel
fontconfig
freetype-devel
giflib-devel
gcc-c++
gtk2-devel
libjpeg-devel
libpng-devel
libxslt
libX11-devel
libXi-devel
libXinerama-devel
libXt-devel
libXtst-devel
pkgconfig
xorg-x11-proto-devel
zip
unzip
java-1.7.0-openjdk-devel
openssl
mercurial
wget
patch
gzip
tar
EOF

yum -y install $(echo $(cat $BRS_FILE))
useradd openjdk

cat > $BUILD_SCRIPT <<EOF
#!/bin/bash
set -e

UPDATE=212
BUILD=b03
NAME="openjdk-8u\${UPDATE}-\${BUILD}"
TARBALL_BASE_NAME="OpenJDK8U"
EA_SUFFIX=""
PLATFORM="x64_linux"
TARBALL_VERSION="8u\${UPDATE}\${BUILD}\${EA_SUFFIX}"
TARBALL_NAME="\${TARBALL_BASE_NAME}-\${PLATFORM}_\${TARBALL_VERSION}"
SOURCE_NAME="\${TARBALL_BASE_NAME}-sources_\${TARBALL_VERSION}"

CLONE_URL=https://hg.openjdk.java.net/jdk8u/jdk8u
TAG="jdk8u\${UPDATE}-\${BUILD}"

clone() {
  url=\$1
  tag=\$2
  targetdir=\$3
  if [ -d \$targetdir ]; then
    echo "Target directory \$targetdir already exists. Skipping clone"
    return
  fi
  hg clone -u \$tag \$url \$targetdir
  pushd \$targetdir
    for i in corba hotspot jaxws jaxp jdk langtools nashorn; do
      hg clone -u \$tag \$url/\$i
    done
  popd
}

build() {
  set -x
  rm -rf build

  # Add patch to be able to build on EL 6
  wget https://bugs.openjdk.java.net/secure/attachment/81610/JDK-8219879.export.patch
  patch -p1 < JDK-8219879.export.patch

  bash common/autoconf/autogen.sh

  # Create a source tarball archive corresponding to the
  # binary build
  tar -c -z -f ../\${SOURCE_NAME}.tar.gz --transform "s|^|\${NAME}-sources/|" --exclude-vcs --exclude='**.patch*' --exclude='overall-build.log' .

  for debug in release slowdebug; do
    bash configure \
       --with-boot-jdk="/usr/lib/jvm/java-1.7.0-openjdk.x86_64" \
       --with-debug-level="\$debug" \
       --with-conf-name="\$debug" \
       --enable-unlimited-crypto \
       --with-milestone="fcs" \
       --with-native-debug-symbols=external \
       --with-cacerts-file=/etc/pki/java/cacerts \
       --with-update-version=\$UPDATE \
       --with-build-number=\$BUILD
    target="bootcycle-images"
    if [ "\${debug}_" == "slowdebug_" ]; then
      target="images"
    fi
    make LOG_LEVEL=debug CONF=\$debug \$target
    # Package it up
    pushd build/\$debug/images
      if [ "\${debug}_" == "slowdebug_" ]; then
        NAME="\$NAME-\$debug"
        TARBALL_NAME="\$TARBALL_NAME-\$debug"
      fi
      mv j2sdk-image \$NAME
      cp src.zip \$NAME
      tar -c -f \${TARBALL_NAME}.tar \$NAME --exclude='**.debuginfo'
      gzip \${TARBALL_NAME}.tar
      tar -c -f \${TARBALL_NAME}-debuginfo.tar \$(find \${NAME}/ -name \*.debuginfo)
      gzip \${TARBALL_NAME}-debuginfo.tar
      rm \$NAME/src.zip
      mv \$NAME j2sdk-image
    popd
  done
  mv ../\${SOURCE_NAME}.tar.gz build/
  set +x
}

clone \$CLONE_URL \$TAG jdk8u
pushd jdk8u
  build 2>&1 | tee overall-build.log
popd
ALL_ARTEFACTS="\$NAME-all-artefacts.tar"
tar -c -f \$ALL_ARTEFACTS \$(echo \$(find jdk8u/build -name \*.tar.gz) jdk8u/overall-build.log)
gzip \$ALL_ARTEFACTS
ls -lh \$(pwd)/*.tar.gz
EOF

cp $BUILD_SCRIPT /home/openjdk
chown -R openjdk /home/openjdk

# Drop privs and perform build
su -c "bash $BUILD_SCRIPT" - openjdk
