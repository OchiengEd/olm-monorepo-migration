# olm-monorepo-migration
OLM v1 Monorepo Migration script

## How to run the script

By default the script `monorepo_prep.sh` expects the [catalogd](https://github.com/operator-framework/catalogd) and [operator-controller](https://github.com/operator-framework/operator-controller) repositories and this repo olm-monorepo-migration at the same directory level.

```
$ ls

catalogd  operator-controller olm-monorepo-migration

```

<details>
<summary>(Alternatively...)</summary>
You may want to nail down these repositories top level directories explicitly.<br>
You may do so by setting environment variables:
<p>
**CATALOGD_REPO_TLD**="../catalogd"<br>
**OPERATOR_CONTROLLER_REPO_TLD**="../operator-controller"<br>
<p>
(the assignments in this example, above, are equivalent to the default behavior initially described and thus the same positional expectations)
</details>
<hr>

Run the script as follows.

```

$ cd olm-monorepo-migration/
$ bash monorepo_prep.sh

```
The script creates a branch named `monorepo` in operator-controller local repository and a branch named `monorepo_prep` in catalogd local repository. The code branch in operator-controller repo would be the pull request for the monorepo work.
