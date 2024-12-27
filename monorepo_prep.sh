#!/usr/bin/env bash

set -e

STAGING_DIR="catalogd"

catalogd_prep() {
    echo "Prepare CatalogD..."
    (cd ../catalogd || return 2

    git checkout -b monorepo_prep

    mkdir -p "${STAGING_DIR}"

    #Cleanly read the output of the `ls -a` command using process substitution
    #filter the list against regex set with an affirmative conditional via the bang `!`
    while read -r file
    do
        # Move files in the repo with exception of the api directory
        if ! [[ "${file}" =~ ^(go.sum|go.mod|.git|.|..)$ ]]
        then
            git mv "${file}" "${STAGING_DIR}";
        else
            #TODO: Remove this else branch during cleanup - not needed beyond debugging
            # Do nothing to any of the above files
            echo -e "skipping ${file}";
        fi
    done < <(ls -a)

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

    local original_makefile="catalogd/Makefile"
    local makefile_patch_data=$(cat <<EOF
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
          )
    patch -p1 "${original_makefile}" <<< "${makefile_patch_data}"

    git add "${original_makefile}"
    git commit -s -m "Update go.mod location in ${original_makefile}"
}


#------
# "Main" function called that kicks off script
#------
main() {

    if catalogd_prep && operator-controller_prep && patch_catalogd_makefile
    then
        echo "Test binaries build"

        if make build-linux
        then
            cd catalogd
            make build-linux
        fi

        echo "Check in generated files"
        git add --all
        git commit -s -m "Check in generated manifest files"
        echo "Done"
    else
        echo "ooops, something went wrong"
        return 1
    fi
}

main "$@"
