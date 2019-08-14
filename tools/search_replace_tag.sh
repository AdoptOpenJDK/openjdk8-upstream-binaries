#!/bin/bash
#
# Takes a tag (TAG) and release type value (RELEASE_TYPE) and replaces
# corresponding tags/ea values in build scripts
#set -xv

usage() {
  echo "Usage: TAG=<tag> RELEASE_TYPE={ea,ga} bash $0" 1>&2
  exit 1
}

EA_SUFFIX=""
checkEnvs() {
  if [ "${TAG}_" == "_" ] || [ "${RELEASE_TYPE}_" == "_" ]; then
    usage
  fi
  case ${RELEASE_TYPE} in
    ga)
       ;;
    ea)
       EA_SUFFIX="_ea"
       ;;
    *)
       echo "Invalid value for RELEASE_TYPE. Got '${RELEASE_TYPE}', expected 'ea|ga'." 1>&2
       echo 1>&2
       usage
  esac
}

parseTag() {
  echo ${TAG} | grep -q -E 'jdk8u[0-9]{3}-b[0-9]{2}'
  if [ $? -ne 0 ]; then
    echo "Error. Unexpected tag name: TAG='${TAG}'." 1>&2
    echo "TAG must be of the form jdk8u[0-9]{3}-b[0-9]{2}" 1>&2
    echo 1>&2
    usage
  fi
  UPDATE_BUILD="$(echo ${TAG} | sed 's/jdk8u\([0-9]\{3\}\)-\(b[0-9]\{2\}\)/\1 \2/')"
  UPDATE=$(echo ${UPDATE_BUILD} | cut -d' ' -f1)
  BUILD=$(echo ${UPDATE_BUILD} | cut -d' ' -f2)
}

debugPrint() {
  if [ ! -z ${DEBUG} ]; then
    echo "EA_SUFFIX=${EA_SUFFIX}"
    echo "BUILD=${BUILD}"
    echo "UPDATE=${UPDATE}"
  fi
}

checkEnvs
parseTag

debugPrint

for f in build-openjdk8.sh install-rhel6-deps-build-openjdk8.sh; do
  sed -i "s|EA_SUFFIX=.*|EA_SUFFIX=\"${EA_SUFFIX}\"|g" $f
  sed -i "s|BUILD=.*|BUILD=${BUILD}|g" $f
  sed -i "s|UPDATE=.*|UPDATE=${UPDATE}|g" $f
done
