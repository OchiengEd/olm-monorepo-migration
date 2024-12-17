# olm-monorepo-migration
OLM v1 Monorepo Migration script

## How to run the script

The script `monorepo_prep.sh` expects the [catalogd](https://github.com/operator-framework/catalogd) and [operator-controller](https://github.com/operator-framework/operator-controller) repositories and this repo olm-monorepo-migration at the same directory level. 

```
$ ls

catalogd  operator-controller olm-monorepo-migration

$ cd olm-monorepo-migration/
$ bash monorepo_prep.sh 

```
The script creates a branch named `monorepo` in operator-controller local repository and a branch named `monorepo_prep` in catalogd local repository. The code branch in operator-controller repo would be the pull request for the monorepo work.