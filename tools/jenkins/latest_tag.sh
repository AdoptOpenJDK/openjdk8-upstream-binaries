#!/bin/bash
#
# Determines the latest tag of the mercurial repository pointed to by
# JDK_REPO. If there is a newer tag found that was written in
# 'latest_tag.txt', then another file 'build_trigger.txt' is being
# produced with the current timestamp (YY-MM-DD HH:mm) as content.
#set -xv

# 8u update cycle release version number
UPDATE=272
JDK_URL=https://hg.openjdk.java.net/jdk8u/jdk8u
JDK_REPO=jdk8u
BASE_PATH="$1"

if [ -z "${WORKSPACE}" ]; then
  WORKSPACE="$(pwd)"
fi

if [ -z "${BASE_PATH}" ]; then
  BASE_PATH="$(pwd)"
fi

check_clone() {
  echo "Checking top HG repo exists..."
  # Ensure parent folder exists
  if [ ! -e "$BASE_PATH" ]; then
    mkdir -p "$BASE_PATH"
  fi
  if [ -d "$BASE_PATH/$JDK_REPO" ]; then
    echo "$JDK_REPO exists, skipping clone."
  else
    pushd $BASE_PATH
      hg clone $JDK_URL $JDK_REPO
    popd
  fi
}

# Export a local home so hg doesn't use some user-local aliases
tmp_dir="$(mktemp -d)"
export HOME=$tmp_dir

echo "Using base path: $BASE_PATH"

# Ensure clone exists
check_clone

pushd "$BASE_PATH/$JDK_REPO"

hg pull -u

LAST_TAG="$(cat ${WORKSPACE}/latest_tag.txt 2> /dev/null || true)"

for i in $(hg log --rev "max(tag('re:jdk8u${UPDATE}-b[0-9]{2}'))" --template "{tags}\n"); do
  echo $i
done | tee revs.txt
num_tags=$(wc -l revs.txt | cut -d' ' -f1)

# One revision might have been tagged multiple times, or we
# might have a swtich from one GA release to the beginning of a
# new update (build 0).
if [ $num_tags -gt 1 ]; then
   candidate=$(sed 's/jdk8u\([0-9]\{3\}\)-b.*/\1/g' revs.txt | sort -n | tail -n1)
   candidates=$(grep $candidate revs.txt | wc -l)
   if [ $candidates -gt 1 ]; then
     # same revision tagged twice (no changes) case
     TAG=$(sort revs.txt | tail -n1)
   else
     # GA => new update case
     TAG=$(grep $candidate revs.txt)
   fi
else
   TAG="$(cat revs.txt)"
fi

if [ -z "$TAG" ]; then
  echo "No tags for update $UPDATE found. This is an error." 1>&2
  exit 1
fi
if ! echo $TAG | grep -q $UPDATE; then
  echo "Latest tag ($TAG) does not match configured update ($UPDATE). This is an error." 1>&2
  echo "It appears a new update cycle has started. Please update te job config" 1>&2
  echo "to the latest update." 1>&2
  exit 1
fi

if [ -z "$LAST_TAG" ]; then
   LATEST_TAG=$TAG
else
   # Check whether we have a newer tag
   num_tags=$(echo -e "$TAG\n$LAST_TAG" | sort | grep -v '^$'| uniq | wc -l)
   if [ $num_tags -gt 1 ]; then
      LATEST_TAG=$(echo -e "$TAG\n$LAST_TAG" | sort | grep -v '^$' | uniq | tail -n1)
   fi
fi

if [ ! -z "$LATEST_TAG" ]; then
  # Add bread-crumbs for downstream build
  date '+%Y-%m-%d %H:%M' > ${WORKSPACE}/build_trigger.txt
  echo "$LATEST_TAG" > ${WORKSPACE}/latest_tag.txt
else
  echo "No new tag found (old tag was $TAG). Nothing to do."
fi

rm -rf $tmp_dir
popd
