#!/bin/bash

PrintUsage()
{
  cat <<EOM
Usage: add_team_to_repos_from_file [options] FILEPATH

Options:
    -h, --help        : Show this message
    -d, --debug       : Enable debug logging
    -o, --org-name    : Name of the org where all repositories and teams exist. If omitted,
                        this script will default to the ORG_NAME environment variable
    -s, --team-slug   : The slug of the team that will be added to each repository
                        If omitted, this script will default to the TEAM_SLUG environment
                        variable
                        Note: To get the slug of a team, visit the team's page in your org
                        and the slug will be in the following location in the url:
                        https://github.com/orgs/<my_org_name>/teams/<MY_TEAM_SLUG>
    -t, --token       : Set Personal Access Token with repo scope - Looks for GITHUB_TOKEN
                        environment variable if omitted

Description:
add_team_to_repos_from_file grants a team access to a list of repositories at a specified permission, provided by a csv

Example:

Given a file "my-repo-file.csv" in the same location as this script with the syntax:

repository-name-1,read
repository-name-2,write
repository-name-3,admin

Run the following comand
  ./add_team_to_repos_from_file -o <org-name> -s <team-slug> ./my-repo-file.csv

EOM
  exit 0
}

####################################
# Read in the parameters if passed #
####################################
PARAMS=""
if [ $# -eq 0 ]; then
  PrintUsage;
fi
while (( "$#" )); do
  case "$1" in
    -h|--help)
      PrintUsage;
      ;;
    -d|--debug)
      DEBUG=true
      shift
      ;;
    -o|--org-name)
      ORG_NAME=$2
      shift 2
      ;;
    -s|--team-slug)
      TEAM_SLUG=$2
      shift 2
      ;;
    -t|--token)
      GITHUB_TOKEN=$2
      shift 2
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

##################################################
# Set positional arguments in their proper place #
##################################################
eval set -- "$PARAMS"

filename=$1

DebugJQ()
{
  # If Debug is on, print it out...
  if [[ $DEBUG == true ]]; then
    echo "$1" | jq '.'
  fi
}

Debug()
{
  # If Debug is on, print it out...
  if [[ $DEBUG == true ]]; then
    echo "$1"
  fi
}

  Debug "curl -kw '%{http_code}' -s --request GET \
  --url \"https://api/github.com/orgs/${ORG_NAME}/teams/${TEAM_SLUG}\" \
  --header 'authorization: Bearer GITHUB_TOKEN' \
  --header 'content-type: application/json'"

  get_team_response=$(curl -kw '%{http_code}' -s --request GET \
  --url "https://api.github.com/orgs/${ORG_NAME}/teams/${TEAM_SLUG}" \
  --header 'authorization: Bearer '"${GITHUB_TOKEN}" \
  --header 'content-type: application/json')

  Debug "${get_team_response}"

  team_response_code="${get_team_response:(-3)}"
  team_data="${get_team_response::${#get_team_response}-4}"

  if [[ "$team_response_code" != "200" ]]; then
      echo "    Error getting Team: ${TEAM_SLUG}"
      echo "${team_response_code}"
      echo "${team_data}"
      team_id=""
  fi

  Debug "DEBUG --- TEAM DATA BLOCK:"
  DebugJQ "${team_data}"

  team_id=$(echo "$team_data" | jq '.id')


if [[ -z $team_id ]]; then
  echo "Error: Team ${TEAM_SLUG} not found in org"
  exit 1
fi

generate_put_data()
{
cat <<EOF
  {
    "permission": "${perm}"
  }
EOF
}

generate_branch_protections()
{
cat <<EOF
  {
    "enforce_admins": true,
    "required_status_checks": {
        "strict": true,
        "contexts": []
    },
    "required_pull_request_reviews": {
        "require_code_owner_reviews": true,
        "required_approving_review_count": 1
    },
    "restrictions": null
EOF
}

perm="push"
while read -r repo
do
      # Add the team to the repo
      echo "Adding repo: ${repo} with permission ${perm}"

      Debug "curl -kw '%{http_code}' -s --request PUT \
      --url \"https://api.github.com/teams/${team_id}/repos/${ORG_NAME}/${repo}\" \
      --header 'Accept: application/vnd.github.hellcat-preview+json' \
      --header 'authorization: Bearer GITHUB_TOKEN' \
      --header 'content-type: application/json' \
      --data \"$(generate_put_data)\""

      add_team_repo_response=$(curl -kw '%{http_code}' -s --request PUT \
      --url "https://api.github.com/teams/${team_id}/repos/${ORG_NAME}/${repo}" \
      --header 'Accept: application/vnd.github.hellcat-preview+json' \
      --header 'authorization: Bearer '"${GITHUB_TOKEN}" \
      --header 'content-type: application/json' \
      --data "$(generate_put_data)")

      if [[ "$add_team_repo_response" != "204" ]]; then
        echo "Error adding repository: ${repo}"
        echo "${add_team_repo_response}"
      else
        echo "Successfully added team to repo: ${repo}"
      fi

      # Add branch protections to the repo
      echo "Adding branch protection rules on ${repo}"
      Debug "curl -kw '%{http_code}' -s -X PUT \
      --url \"https://api.github.com/repos/${ORG_NAME}/${repo}/branches/main/protection\" \
      --header 'Accept: application/vnd.github.luke-cage-preview+json' \
      --header 'authorization: Bearer GITHUB_TOKEN' \
      --header 'content-type: application/json' \
      --data \"$(generate_branch_protections)\""

      add_branch_protection_rules=$(curl -kw '%{http_code}' -s -X PUT \
      --url "https://api.github.com/repos/${ORG_NAME}/${repo}/branches/main/protection" \
      --header 'Accept: application/vnd.github.luke-cage-preview+json' \
      --header 'authorization: Bearer '"${GITHUB_TOKEN}" \
      --header 'content-type: application/json' \
      --data "$(generate_branch_protections)")

      add_branch_protection_rules_code=$(echo "$add_branch_protection_rules" | tail -n 1)
      if [[ "$add_branch_protection_rules_code" != "200" ]]; then
        echo "Error adding repository branch protection: ${repo}"
        echo "${add_branch_protection_rules}"
      else
        echo "Successfully added branch protections to repo: ${repo}"
      fi
done < "${filename}"
