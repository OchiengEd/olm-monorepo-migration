#!/bin/bash

STAGING_DIR="catalogd"

function catalogd_prep() {
    cd ../catalogd
    
    git checkout -b monorepo_prep
    
    FILES=`ls -a`
    
    mkdir "${STAGING_DIR}"
    
    for f in ${FILES}
    do
        # Move files in the repo with exception of the api directory
        if [[ "${f}" = "go.sum" || "${f}" = "go.mod" || "${f}" = ".git" ]]
        then
            # Do nothing to any of the above files
            echo -e "\n";
        else
            git mv "${f}" "${STAGING_DIR}";
        fi
    done

    # Rename import paths
    find . -name "*.go" -type f -exec sed -i 's|github.com/operator-framework/catalogd|github.com/operator-framework/operator-controller/catalogd|g' {} \;

    git add .

    git commit -s -m "Monorepo prep commit"

    cd -
}

function operator-controller_prep() {
    echo "Prepare operator-controller repo"

    cd ../operator-controller

    git checkout origin/main -b monorepo

    git remote add -f catalogd ../catalogd

    git fetch catalogd

    # Update catalogd API imports
    find . -name "*.go" -type f -exec sed -i 's|github.com/operator-framework/catalogd|github.com/operator-framework/operator-controller/catalogd|g' {} \;

    git add --all

    git commit -s -m "Update catalogd API v1 imports"

    git merge catalogd/monorepo_prep --no-commit --allow-unrelated-histories

    git checkout --ours go.mod

    git checkout --ours go.sum

    git add go.mod go.sum

    git commit -s -m "Merge catalogd/monorepo_prep branch into operator-controller"

    # Drop catalogd imports in go.mod
    sed -i '/catalogd/d' go.mod

    go mod tidy

    git add go.mod go.sum

    git commit -s -m "Remove redundant catalogd import"
}

catalogd_prep
operator-controller_prep
