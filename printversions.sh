#!/bin/sh
cd $(dirname $0)
cd ..

ROOT=`pwd`

echo "This contains the versions that were used to build the binary."

folders=( monodevelop-build MonoDevelop.Debugger.Soft.Unity unityscript monodevelop MonoDevelop.Boo.UnityScript.Addins boo boo-extensions )

for folder in "${folders[@]}"
do
	cd ${ROOT}/$folder
	echo ""
	echo "Repository    `git config --get remote.origin.url`.git"
	echo "Branch        `git rev-parse --abbrev-ref HEAD`"
	echo "Revision      `git rev-parse HEAD`"
done