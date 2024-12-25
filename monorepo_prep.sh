#!/usr/bin/env bash

set -e

STAGING_DIR="catalogd"

catalogd_prep() {
    (cd ../catalogd || return 2

    git checkout -b monorepo_prep

    FILES=$(ls -a)

    mkdir -p "${STAGING_DIR}"

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
    git commit -s -m "Monorepo prep commit")
}

operator-controller_prep() {
    echo "Prepare operator-controller repo"

    cd ../operator-controller || return 2
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

patch_catalogd_makefile() {
    echo "Update catalogd Makefile"
    cat <<EOF> makefile.patch
--- Makefile	2024-12-12 15:30:54.148960768 -0600
+++ Makefile.2	2024-12-12 15:30:12.246138930 -0600
@@ -3,7 +3,7 @@
 SHELL := /usr/bin/env bash -o pipefail
 .SHELLFLAGS := -ec

-GOLANG_VERSION := \$(shell sed -En 's/^go (.*)\$\$/\1/p' "go.mod")
+GOLANG_VERSION := \$(shell sed -En 's/^go (.*)\$\$/\1/p' "../go.mod")

 ifeq (\$(origin IMAGE_REPO), undefined)
 IMAGE_REPO := quay.io/operator-framework/catalogd
EOF

    patch -p1 catalogd/Makefile < makefile.patch

    if [ -f ./makefile.patch ]
    then
        rm -fv makefile.patch
    fi

    git add catalogd/Makefile
    git commit -s -m "Update go.mod location in catalogd/Makefile"
}

catalogd_prep
operator-controller_prep
patch_catalogd_makefile

echo "Test binaries build"
make build-linux
if [ $? -eq 0 ]
then
    cd catalogd
    make build-linux
fi

echo "Check in generated files"
git add --all
git commit -s -m "Check in generated manifest files"
