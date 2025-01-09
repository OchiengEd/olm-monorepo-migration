#!/bin/bash

STAGING_DIR="catalogd"

function catalogd_prep() {
    echo "Preparing catalogd repository..."
    cd ../catalogd || exit 1

    # Remove the branch if it already exists
    if git branch --list monorepo_prep_camila > /dev/null; then
        git branch -D monorepo_prep_camila
    fi

    git checkout -b monorepo_prep_camila

    FILES=$(ls -A)

    mkdir -p "${STAGING_DIR}"

    for f in ${FILES}
    do
        # Move files in the repo with exception of the api directory and certain files
        if [[ "${f}" != "go.sum" && "${f}" != "go.mod" && "${f}" != ".git" && "${f}" != "${STAGING_DIR}" ]]; then
            git mv "${f}" "${STAGING_DIR}/"
        fi
    done

    # Rename import paths
    find . -name "*.go" -type f -exec sed -i '' 's|github.com/operator-framework/catalogd|github.com/operator-framework/operator-controller/catalogd|g' {} \;

    git add .
    git commit -s -m "Monorepo prep commit"

    cd - || exit 1
}

function operator_controller_prep() {
    echo "Preparing operator-controller repository..."
    cd ../operator-controller || exit 1

    # Remove the branch if it already exists
    if git branch --list monorepo_camila > /dev/null; then
        git branch -D monorepo_camila
    fi

    git checkout origin/main -b monorepo_camila

    git remote add catalogd ../catalogd || echo "Remote 'catalogd' already exists."

    git fetch catalogd

    # Update catalogd API imports
    find . -name "*.go" -type f -exec sed -i '' 's|github.com/operator-framework/catalogd|github.com/operator-framework/operator-controller/catalogd|g' {} \;

    git add --all
    git commit -s -m "Update catalogd API v1 imports"

    git merge catalogd/monorepo_prep_camila --no-commit --allow-unrelated-histories

    git checkout --ours go.mod
    git checkout --ours go.sum

    git add go.mod go.sum
    git commit -s -m "Merge catalogd/monorepo_prep_camila branch into operator-controller"

    # Drop catalogd imports in go.mod
    sed -i '' '/catalogd/d' go.mod

    go mod tidy

    git add go.mod go.sum
    git commit -s -m "Remove redundant catalogd import"
}

function patch_catalogd_makefile() {
    echo "Updating catalogd Makefile..."
    cat <<EOF > makefile.patch
--- Makefile
+++ Makefile
@@ -3,7 +3,7 @@
 SHELL := /usr/bin/env bash -o pipefail
 .SHELLFLAGS := -ec

-GOLANG_VERSION := \$(shell sed -En 's/^go (.*)\$\$/\1/p' "go.mod")
+GOLANG_VERSION := \$(shell sed -En 's/^go (.*)\$\$/\1/p' "../go.mod")

 ifeq (\$(origin IMAGE_REPO), undefined)
 IMAGE_REPO := quay.io/operator-framework/catalogd
EOF

    patch -p1 < makefile.patch

    rm -f makefile.patch

    git add catalogd/Makefile
    git commit -s -m "Update go.mod location in catalogd/Makefile"
}

function test_binaries_build() {
    echo "Testing binaries build..."
    make build-linux || exit 1
    cd catalogd || exit 1
    make build-linux || exit 1
    cd - || exit 1
}

function check_in_generated_files() {
    echo "Checking in generated files..."
    git add --all
    git commit -s -m "Check in generated manifest files"
}

# Execute the steps
catalogd_prep
operator_controller_prep
patch_catalogd_makefile
test_binaries_build
check_in_generated_files

echo "Monorepo preparation completed successfully."
