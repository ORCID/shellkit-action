#!/usr/bin/env bash

version=${1:-main}

if [ -d /tmp/shellkit_bump ];then
  rm -Rf /tmp/shellkit_bump
fi
mkdir /tmp/shellkit_bump

shellkit_clone_dir=/tmp/shellkit_bump/shellkit-$version
git clone git@github.com:ORCID/shellkit.git --branch $version $shellkit_clone_dir

for file in lib/*;do
  echo "$file"
  cp $shellkit_clone_dir/$file $file
done

for file in bin/*;do
  echo "$file"
  cp $shellkit_clone_dir/$file $file
done

