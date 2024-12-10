#!/bin/bash

function catalogd_prep() {
    cd ../catalogd
    
    git checkout -b monorepo_prep
    
    FILES=`ls`
    
    mkdir catalogd_root
    
    for f in ${FILES}
    do
        # Move files in the repo with exception 
        # of the api directory
        if [ "${f}" != "api" ]
        then
            git mv "${f}" catalogd_root;
        fi
    done
    
    HIDDEN_FILES=(".goreleaser.yml" ".github" ".gitignore" ".golangci.yaml" ".dockerignore" ".bingo")
    for ff in "${HIDDEN_FILES[@]}";
    do
        git mv "${ff}" "catalogd_root/_${ff}";
    done
    
    git commit -s -m "Monorepo prep commit"
}

function operator-controller_prep() {
    echo "Prepare operator-controller repo"
}

function merge_catalogd() {
    echo "Merge catalogd_prep work into operator-controller"
}

catalogd_prep
operator-controller_prep
merge_catalogd
