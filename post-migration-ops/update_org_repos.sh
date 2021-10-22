#!/bin/bash

ORG_NAME=$1
GITHUB_TOKEN=$2

#########################################################################
#### Write all the repos from the org into the repositories.csv file ####
#########################################################################
sh 1_get_all_repos.sh "$ORG_NAME" "$GITHUB_TOKEN"

####################################################################
#### Update the default branch and create main in all the repos ####
####################################################################
sh 2_update_default_branch.sh "$ORG_NAME" "$GITHUB_TOKEN"

##################################################################
#### Update brach protection rules and add the employees team ####
##################################################################
sh 3_add_teams_and_protection_to_repos.sh --team-slug "employees" --org-name "$ORG_NAME" --token "$GITHUB_TOKEN" ./repositories.csv