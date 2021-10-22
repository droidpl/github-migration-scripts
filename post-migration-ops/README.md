# Post-migration script for GHES to GHEC

## GitHub.com post migration
This script will:
- List all the repositories in the organization
- For each repository:
  - Update the default branch from master to main
  - Add the default branch protection rules
  - Add the `Employees` team with write access in the repository

## Pre-conditions
- Running in a Unix system
- In the GitHub organization there is an `Employees` team
- `jq` is installed in the system

## How to run

To run this script you will need the following arguments:
- The name of the organization
- A Personal Access Token (PAT) scoped with enough permissions to perform the operations (preferably with admin:org scope)

You can run the script with the following command:

```sh
sh update_org_repos.sh $ORG_NAME $GITHUB_PAT
```

## GitHub Server post migration

To remove the lock from the repositories you can run:
```
ghe-migrator unlock -g $MIGRATION_GUID
```

Then you can archive all the repositories running:
```
./archive_all_repos_ghe.sh
```
