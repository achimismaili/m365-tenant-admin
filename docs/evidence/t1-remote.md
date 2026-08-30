# T1 — GitHub remote creation

**Status:** ✅ **SUCCEEDED.** No manual step is required. This document records the exact
commands run and the one flag incompatibility that had to be worked around.

| | |
|---|---|
| Repository | `achimismaili/m365-tenant-admin` |
| URL | https://github.com/achimismaili/m365-tenant-admin |
| Visibility | **Public** |
| Licence detected by GitHub | MIT License (`mit`) |
| Default branch | `main`, tracking `origin/main` |
| Scaffold commit | `4d46032` — `chore: scaffold m365-tenant-admin toolkit (MIT)` |
| Date | 2026-08-30 |

## Environment

```
gh version 2.97.0 (2026-07-31)
gh auth status → ✓ Logged in to github.com account achimismaili (keyring)
                 Token scopes: 'delete_repo', 'gist', 'read:org', 'repo', 'workflow'
```

The `repo` scope was present, which is what `gh repo create` requires. No interactive prompt was
triggered, so the command ran cleanly in a non-interactive shell.

## Attempt 1 — failed (flag incompatibility, not an auth problem)

The command specified in the plan was run verbatim:

```powershell
gh repo create m365-tenant-admin --public --license MIT --source=. --remote=origin
```

It exited **1** with:

```
the `--source` option is not supported with `--clone`, `--template`, `--license`, or `--gitignore`
```

**Why:** `--license` and `--gitignore` ask GitHub to *generate* those files server-side into a new,
empty repository. `--source=.` instead adopts an existing local repository that already has its own
history. The two are mutually exclusive by design.

This is not a blocker: the MIT `LICENSE` file was already written and committed locally as part of
the scaffold, so `--license MIT` was redundant. GitHub's licence detector reads the committed
`LICENSE` file and correctly reports `MIT License` for the repository (verified below).

## Attempt 2 — succeeded

```powershell
gh repo create m365-tenant-admin `
  --public `
  --source=. `
  --remote=origin `
  --push `
  --description "Tool-agnostic toolkit for administering Microsoft 365 tenants from the command line"
```

Exited **0**:

```
https://github.com/achimismaili/m365-tenant-admin
branch 'main' set up to track 'origin/main'.
To https://github.com/achimismaili/m365-tenant-admin.git
 * [new branch]      HEAD -> main
```

## Verification

```
$ git remote -v
origin  https://github.com/achimismaili/m365-tenant-admin.git (fetch)
origin  https://github.com/achimismaili/m365-tenant-admin.git (push)

$ git log --oneline --decorate
4d46032 (HEAD -> main, origin/main) chore: scaffold m365-tenant-admin toolkit (MIT)

$ git status --short --branch
## main...origin/main

$ gh repo view achimismaili/m365-tenant-admin --json name,visibility,url,licenseInfo
{"licenseInfo":{"key":"mit","name":"MIT License","nickname":""},
 "name":"m365-tenant-admin",
 "url":"https://github.com/achimismaili/m365-tenant-admin",
 "visibility":"PUBLIC"}
```

`origin/main` is present in the log decoration and `git status --short --branch` shows no
ahead/behind marker, so the push landed and local and remote are identical.

## Reproducing this on a machine without `gh`

Not needed here, but recorded so the step is not rediscovered. Create an empty repository named
`m365-tenant-admin` under the target account via the GitHub web UI — **without** adding a README,
`.gitignore` or licence, since the local repository already supplies all three and a server-side
initial commit would force an unnecessary merge. Then:

```powershell
git remote add origin https://github.com/<account>/m365-tenant-admin.git
git push -u origin main
```
