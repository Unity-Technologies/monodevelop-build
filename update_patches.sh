#!/bin/sh
cd $(dirname $0)
CURRENT=`pwd`
cd ..
ROOT=`pwd`

BASE_BRANCH="unity-trunk"
PATCH_BRANCH="unity-trunk-patch"

echo "Update patches with base branch ${BASE_BRANCH} and patch branch ${PATCH_BRANCH}"

cd ${ROOT}/monodevelop

git checkout ${PATCH_BRANCH}
git pull origin ${PATCH_BRANCH}
git checkout ${BASE_BRANCH}
git pull origin ${BASE_BRANCH}

git diff ${BASE_BRANCH}...${PATCH_BRANCH} > ${CURRENT}/patches/monodevelop.patch

cd ${ROOT}/debugger-libs

git checkout ${PATCH_BRANCH}
git pull origin ${PATCH_BRANCH}
git checkout ${BASE_BRANCH}
git pull origin ${BASE_BRANCH}

git diff ${BASE_BRANCH}...${PATCH_BRANCH} > ${CURRENT}/patches/debugger-libs.patch

cd ${ROOT}/mono-addins

git checkout ${PATCH_BRANCH}
git pull origin ${PATCH_BRANCH}
git checkout ${BASE_BRANCH}
git pull origin ${BASE_BRANCH}

git diff ${BASE_BRANCH}...${PATCH_BRANCH} > ${CURRENT}/patches/mono-addins.patch
