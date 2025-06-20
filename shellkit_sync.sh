#!/usr/bin/env bash

version=${1:-main}

mkdir /tmp/shellkit_bump

shellkit_clone_dir=/tmp/shellkit_bump/shellkit-$version
git clone git@github.com:ORCID/shellkit.git --branch $version $shellkit_clone_dir

for file in lib/*;do
  echo "$file"
  cp $shellkit_clone_dir/$file $file
done

