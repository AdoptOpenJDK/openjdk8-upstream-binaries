#!/bin/bash
set -e

# Determine platform name. Currently supported:
#
# x86_64 => x64_linux
# aarch64 => aarch64_linux
#
platform_name() {
  arch=$(uname -m)
  case $arch in
  x86_64)
    echo "x64_linux"
    ;;
  aarch64)
    echo "aarch64_linux"
    ;;
  *)
    echo "Unsupported platform '$arch'" 1>&2
    exit 1
    ;;
  esac
}

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

# On some build hosts available disk size of /home
# is insufficient for building OpenJDK in release and
# slowdebug configurations. Be sure to bind-mount
# an appropriate slice of / for the build to succeed.
THRESHOLD_DISK_SIZE="10"
AVAIL_HOME="$(echo $(df -P --block-size=G /home | tail -n1 | awk '{print $4}' | sed 's/G//g'))"
AVAIL_OPT="$(echo $(df -P --block-size=G /opt | tail -n1 | awk '{print $4}' | sed 's/G//g'))"
if [ ${AVAIL_HOME} -lt ${THRESHOLD_DISK_SIZE} ]; then
  # Some diagnostic output
  df -P -h
  if [ ${AVAIL_OPT} -lt ${THRESHOLD_DISK_SIZE} ]; then
    # Nothing we can do, the build host seems not suitable
    echo "Neither /home nor /opt have sufficient disk space available. This is an error." 1>&2
    exit 1
  fi
  # Preconditions met. Bind mount a slice of /opt
  if [ ! -e /opt/openjdk ]; then
    mkdir /opt/openjdk
  fi
  if [ ! -e /home/openjdk ]; then
    mkdir /home/openjdk
  fi
  echo -n "Bind-mounting /opt/openjdk (Avail: ${AVAIL_OPT}G) to "
  echo "/home/openjdk (Avail: ${AVAIL_HOME}G) for disk space reasons."
  mount -o bind /opt/openjdk /home/openjdk
else
  echo "Disk space of /home seems sufficient: Avail: ${AVAIL_OPT}G"
fi

useradd openjdk

# Note: platform_name intentionally not escaped
cat > $BUILD_SCRIPT <<EOF
#!/bin/bash
set -e

UPDATE=302
BUILD=b05
NAME="openjdk-8u\${UPDATE}-\${BUILD}"
JRE_NAME="\${NAME}-jre"
TARBALL_BASE_NAME="OpenJDK8U"
EA_SUFFIX="_ea"
PLATFORM="$(platform_name)"
TARBALL_VERSION="8u\${UPDATE}\${BUILD}\${EA_SUFFIX}"
PLATFORM_VERSION="\${PLATFORM}_\${TARBALL_VERSION}"
TARBALL_NAME="\${TARBALL_BASE_NAME}-jdk_\${PLATFORM_VERSION}"
TARBALL_NAME_JRE="\${TARBALL_BASE_NAME}-jre_\${PLATFORM_VERSION}"
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
  # On some systems the per user process limit is set too low
  # by default (e.g. 1024). This may make the build fail on
  # systems with many cores (e.g. 64). Raise the limit to 1/2
  # of the maximum amount of threads allowed by the kernel.
  if [ -e /proc/sys/kernel/threads-max ]; then
    ulimit -u \$(( \$(cat /proc/sys/kernel/threads-max) / 2))
  fi

  rm -rf build

  # Add patch to be able to build on EL 6
  wget https://bugs.openjdk.java.net/secure/attachment/81610/JDK-8219879.export.patch
  patch -p1 < JDK-8219879.export.patch

  bash common/autoconf/autogen.sh

  # Create a source tarball archive corresponding to the
  # binary build
  tar -c -z -f ../\${SOURCE_NAME}.tar.gz --transform "s|^|\${NAME}-sources/|" --exclude-vcs --exclude='**.patch*' --exclude='overall-build.log' .

  MILESTONE="fcs"
  if [ "\${EA_SUFFIX}_" != "_" ]; then
    MILESTONE="ea"
  fi

  for debug in release slowdebug; do
    bash configure \
       --with-boot-jdk="/usr/lib/jvm/java" \
       --with-debug-level="\$debug" \
       --with-conf-name="\$debug" \
       --enable-unlimited-crypto \
       --with-milestone="\$MILESTONE" \
       --with-native-debug-symbols=external \
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
      # JDK package
      mv j2sdk-image \$NAME
      cp src.zip \$NAME
      tar -c -f \${TARBALL_NAME}.tar --exclude='**.debuginfo' \$NAME
      gzip \${TARBALL_NAME}.tar
      tar -c -f \${TARBALL_NAME}-debuginfo.tar \$(find \${NAME}/ -name \*.debuginfo)
      gzip \${TARBALL_NAME}-debuginfo.tar
      rm \$NAME/src.zip
      mv \$NAME j2sdk-image
      # JRE package (release only)
      if [ "\${debug}_" == "release_" ]; then
        mv j2re-image \$JRE_NAME
        tar -c -f \${TARBALL_NAME_JRE}.tar --exclude='**.debuginfo' \$JRE_NAME
        gzip \${TARBALL_NAME_JRE}.tar
        tar -c -f \${TARBALL_NAME_JRE}-debuginfo.tar \$(find \${JRE_NAME}/ -name \*.debuginfo)
        gzip \${TARBALL_NAME_JRE}-debuginfo.tar
        mv \$JRE_NAME j2re-image
      fi
    popd
  done
  mv ../\${SOURCE_NAME}.tar.gz build/
  set +x
}

TARGET_FOLDER="jdk8u"
clone \$CLONE_URL \$TAG \$TARGET_FOLDER
pushd \$TARGET_FOLDER
  build 2>&1 | tee overall-build.log
popd
ALL_ARTEFACTS="\$NAME\$EA_SUFFIX-$(platform_name)-all-artefacts.tar"
tar -c -f \$ALL_ARTEFACTS --transform "s|^\$TARGET_FOLDER/|\$NAME\$EA_SUFFIX-all-artefacts/$(platform_name)/|g" \$(echo \$(find \$TARGET_FOLDER/build -name \*.tar.gz) \$TARGET_FOLDER/overall-build.log)
gzip \$ALL_ARTEFACTS
ls -lh \$(pwd)/*.tar.gz
EOF

cp $BUILD_SCRIPT /home/openjdk
chown -R openjdk /home/openjdk

# Drop privs and perform build
su -c "bash $BUILD_SCRIPT" - openjdk
