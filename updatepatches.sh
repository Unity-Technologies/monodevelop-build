#!/bin/sh
cd $(dirname $0)
CURRENT=`pwd`
cd ..
ROOT=`pwd`

cd ${ROOT}/monodevelop

git checkout unity-trunk-patch-monodevelop-6.x
git pull origin unity-trunk-patch-monodevelop-6.x
git checkout unity-trunk-monodevelop-6.x
git pull origin unity-trunk-monodevelop-6.x

git diff unity-trunk-monodevelop-6.x...unity-trunk-patch-monodevelop-6.x > ${CURRENT}/patches/monodevelop.patch

# cd ${ROOT}/debugger-libs

# git checkout unity-trunk-patch
# git pull origin unity-trunk-patch
# git checkout unity-trunk
# git pull origin unity-trunk

# git diff unity-trunk...unity-trunk-patch > ${CURRENT}/patches/debugger-libs.patch

# cd ${ROOT}/mono-addins

# git checkout unity-trunk-patch
# git pull origin unity-trunk-patch
# git checkout unity-trunk
# git pull origin unity-trunk

# git diff unity-trunk...unity-trunk-patch > ${CURRENT}/patches/mono-addins.patch
