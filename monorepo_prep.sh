#!/usr/bin/env bash

set -u
set -o pipefail

DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}

#---
# A bit of prerequisite command existence checking
#---
{
    sed_cmd="sed"
    if grep -q -i "daRwiN" <<< $(uname) ; then
        if type gsed >& /dev/null;
        then
            ((VERBOSE)) && echo "Now using gsed";
            sed_cmd=gsed;
        else
            printf "\n missing required tool \033[01;33m %s \033[0m \n" "gsed"  ;
            echo " Your mac doesn't have a suitable sed. You cannot use this script, please install gsed!!";
            exit 1;
        fi
    fi

    num_missing_tools=0
    if type find  >& /dev/null; then echo -n "."; else printf "\n missing required tool \033[01;33m %s \033[0m " "find" ; (( num_missing_tools++ ));fi
    if type git   >& /dev/null; then echo -n "."; else printf "\n missing required tool \033[01;33m %s \033[0m " "git"  ; (( num_missing_tools++ ));fi
    if type go    >& /dev/null; then echo -n "."; else printf "\n missing required tool \033[01;33m %s \033[0m " "go"   ; (( num_missing_tools++ ));fi
    if type patch >& /dev/null; then echo -n "."; else printf "\n missing required tool \033[01;33m %s \033[0m " "patch"; (( num_missing_tools++ ));fi
    if type ${sed_cmd} >& /dev/null; then echo -n "."; else printf "\n missing required tool \033[01;33m %s \033[0m " "${sed_cmd}"  ; (( num_missing_tools++ ));fi
    echo
    ((num_missing_tools > 0)) && exit 2 || echo
}
set -e
#---

CATALOGD_REPO_TLD=${CATALOGD_REPO_TLD:-"../catalogd"}
OPERATOR_CONTROLLER_REPO_TLD=${OPERATOR_CONTROLLER_REPO_TLD:-"../operator-controller"}

echo "catalogd repo: ${CATALOGD_REPO_TLD}"
echo "operator-controller repo : ${OPERATOR_CONTROLLER_REPO_TLD}"

STAGING_DIR="catalogd"

catalogd_prep() {
    echo "Prepare CatalogD..."
    (cd "${CATALOGD_REPO_TLD}" || return 2
    pwd
    git checkout -b monorepo_prep

    mkdir -p "${STAGING_DIR}"

    #Cleanly read the output of the `ls -a` command using process substitution
    #filter the list against regex set with an affirmative conditional via the bang `!`
    echo "    GIT Moving files to staging dir: ${STAGING_DIR}"
    while read -r file
    do
        # Move files in the repo with exception of the api directory
        if ! [[ "${file}" =~ ^(go.sum|go.mod|.git|.|..)$ ]]
        then
            git mv "${file}" "${STAGING_DIR}";
        else
            #TODO: Remove this else branch during cleanup - not needed beyond debugging
            # Do nothing to any of the above files
            ((DEBUG)) && echo -e "skipping ${file}";
        fi
    done < <(ls -a)

    # Rename import paths
    echo "    Editing go files with new import paths..."
    find . -name "*.go" -type f -exec ${sed_cmd} -i 's|github.com/operator-framework/catalogd|github.com/operator-framework/operator-controller/catalogd|g' {} \;
    git add .
    git commit -s -m "Monorepo prep commit")
}

operator-controller_prep() {
    echo "Prepare operator-controller repo"

    (cd "${OPERATOR_CONTROLLER_REPO_TLD}" || return 2
    pwd
    git checkout origin/main -b monorepo
    git remote add -f catalogd "${CATALOGD_REPO_TLD}"
    git fetch catalogd

    # Update catalogd API imports
    ((VERBOSE)) && echo "    Editing go files with new import paths..."
    find . -name "*.go" -type f -exec ${sed_cmd} -i 's|github.com/operator-framework/catalogd|github.com/operator-framework/operator-controller/catalogd|g' {} \;
    git add --all
    git commit -s -m "Update catalogd API v1 imports"
    git merge catalogd/monorepo_prep --no-commit --allow-unrelated-histories
    git checkout --ours go.mod
    git checkout --ours go.sum
    git add go.mod go.sum
    git commit -s -m "Merge catalogd/monorepo_prep branch into operator-controller"

    # Drop catalogd imports in go.mod
    ((VERBOSE)) && echo "    Editing go.mod to remove catalogd from imports..."
    ${sed_cmd} -i '/catalogd/d' go.mod

    go mod tidy

    git add go.mod go.sum
    git commit -s -m "Remove redundant catalogd import")
}

patch_catalogd_makefile() {
    echo "Update catalogd Makefile"

    (cd "${OPERATOR_CONTROLLER_REPO_TLD}" || return 2
    pwd
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
    echo "--->> Makefile to edit: $(readlink -f ${original_makefile})"
    patch -p1 "${original_makefile}" <<< "${makefile_patch_data}"
    ((VERBOSE)) && echo "    Patched Makefile"
    git add "${original_makefile}"
    git commit -s -m "Update go.mod location in ${original_makefile}"
    )
}


#------
# Functions to undo and clean up repos (helps with dev iteration cycle speed)
#------

# "private" functions
_undo_catalogd_prep() {
    echo "UNDOING catalogd_prep..."

    (cd "${CATALOGD_REPO_TLD}" || return 2
    pwd
    git checkout main
    echo "branches before removal"
    git branch -vv
    git branch -D monorepo_prep
    echo "branches after removal"
    git branch -vv
    ) && echo "undone" || echo "could not undo catalogd_prep"
}

_undo_operator-controller_prep() {
    echo "UNDOING operator_controller_prep..."

    (cd "${OPERATOR_CONTROLLER_REPO_TLD}" || return 3
    pwd
    git checkout main

    echo "removing monorepo branch"
    git branch -vv
    git branch -D monorepo
    git branch -vv

    echo "removing catalogd remote"
    echo "remotes before removal"
    git remote -vv
    git remote remove catalogd
    echo "remotes after removal"
    git remote -vv
    ) && echo "undone" || echo "could not undo operator-controller_prep"
}

# "public" function
undo_monorepo() {
    _undo_catalogd_prep
    _undo_operator-controller_prep
}

usage() {
    printf "
usage:

> %s [[--help | -h] | --undo]

  --help | -h    : shows this message
  --undo         : reverses the monorepo process (please don't use if you have pushed!)
    <\"\">         : with no args will run the monorepo process

  The script responds to DEBUG and VERBOSE environment variables.
  Set these to a non zero value, usually \"1\" and run the command,
  additional information will be included in the stdout output.

        How to run this script:

        The script %s expects the catalogd and
        operator-controller repositories and this repo
        olm-monorepo-migration at the same directory level.

        $ ls

        catalogd  operator-controller olm-monorepo-migration

        $ cd olm-monorepo-migration/
        $ bash %s

        The script creates a branch named monorepo in
        operator-controller local repository and a branch named
        monorepo_prep in catalogd local repository. The code branch in
        operator-controller repo would be the pull request for the
        monorepo work.

        see: https://github.com/OchiengEd/olm-monorepo-migration

Examples:

$ DEBUG=1 VERBOSE=1 %s
$ %s --undo


" "${0##*/}" "${0##*/}" "${0##*/}" "${0##*/}" "${0##*/}"
    exit 0
}
#------
# "Main" function called that kicks off script
#------
main() {

    # no args: then let's get it on...
    if (( $# == 0 )); then
        if catalogd_prep && operator-controller_prep && patch_catalogd_makefile
        then
            echo "Test binaries build"
            (cd "${OPERATOR_CONTROLLER_REPO_TLD}"
            if make build-linux
            then
                cd catalogd
                make build-linux
            fi

            echo "Check in generated files"
            git add --all
            git commit -s -m "Check in generated manifest files"
            echo "Done")
            exit $?
        else
            echo "ooops, something went wrong"
            exit 1
        fi

    else # args: then let's handle them...
        while (( $# > 0 )); do
            case "$1" in
                --help|-h)
                    shift
                    usage
                    ;;
                --undo)
                    shift
                    undo_monorepo
                    exit $?
                    ;;
                *)
                    echo "unknown arg $1"
                    shift
                    ;;
            esac
        done
    fi
}

main "$@"
