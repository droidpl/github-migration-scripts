# Migration script

## Introduction

This script helps on renaming in bulk repositories from an organization.

## Executing

To run this program you need to:
- Create a `.env` file in the `rename-repos` directory
- Add a `GITHUB_TOKEN` variable to the `.env` file
- Add the csv file to the `rename-repos` directory with the repositories to rename
- Run the script

To run the script:
```bash
$ cd rename-repos
$ npm install
$ npm run start
```