#!/bin/bash

function catalogd_prep() {
    cd ../catalogd
    
    git checkout -b monorepo_prep
    
    FILES=`ls -a`
    
    mkdir catalogd_root
    
    for f in ${FILES}
    do
        # Move files in the repo with exception 
        # of the api directory
        if [[ "${f}" = "go.sum" || "${f}" = "go.mod"  || "${f}" = "api" || "${f}" = ".git" || "${f}" = ".gitignore"  ]]
        then
            # Do nothing to any of the above files
            echo -e "\n";
        else
            git mv "${f}" catalogd_root;
        fi
    done

    # Rename import paths
    grep -rl "github.com/operator-framework/catalogd/internal" . | xargs -n 1 sed -i 's|github.com/operator-framework/catalogd/internal|github.com/operator-framework/catalogd/catalogd_root/internal|g'
    
    grep -rl "github.com/operator-framework/catalogd/test" . | xargs -n 1 sed -i 's|github.com/operator-framework/catalogd/test|github.com/operator-framework/catalogd/catalogd_root/test|g'

    git add .

    git commit -s -m "Monorepo prep commit"

    cd -
}

function operator-controller_prep() {
    cd ../operator-controller
    pwd
    echo "Prepare operator-controller repo"
}

function merge_catalogd() {
    echo "Merge catalogd_prep work into operator-controller"
}

catalogd_prep
operator-controller_prep
merge_catalogd
