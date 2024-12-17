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