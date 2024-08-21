#!/usr/bin/env bash

version=${1:-v0.14.1}

mkdir /tmp/asdf_bump

asdf_clone_dir=/tmp/asdf_bump/asdf-$version
git clone https://github.com/asdf-vm/asdf.git --branch $version $asdf_clone_dir


rsync -avz --exclude 'asdf.fish' --exclude 'asdf.nu' --exclude 'asdf.ps1' \
            --exclude '*.md' --exclude 'test/*' --exclude 'scripts/*' --exclude 'docs/*' \
            $asdf_clone_dir/* asdf/


