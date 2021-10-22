#!/bin/bash
################################################################################
################################################################################
####### Archive All Repos in Org @AdmiralAwkbar ################################
################################################################################
################################################################################

# LEGEND:
# This script will use pagination and the github API to collect a list
# of all repos for an organization.
# It will then archive all repositories in that GitHub Organization.
# This is useful when you migrate a user from GHE to GitHub.com or vice versa
# and need to archive the old side
#
# PREREQS:
# You need to have the following to run this script successfully:
# - GitHub Personal Access Token with access to the Organization
# - Name of the Organization to query
# - jq installed on the machine running the query
#

###########
# GLOBALS #
###########
GITHUB_API='https://url/api' # API URL
GRAPHQL_URL="$GITHUB_API/graphql"   # URL endpoint to graphql
PAGE_SIZE=100           # Default is 100, GitHub limit is 100
END_CURSOR='null'       # Set to null, will be updated after call
TOTAL_REPO_COUNT=0      # Counter of all repos found
DEBUG=0                 # 0=Debug OFF | 1=Debug ON
ORG_REPOS=()            # Array of all repos found in Org

##############
# USER INPUT #
##############
DRY_RUN=''    # Flag for dry run to show the output 1=no archive | 0=archive
ORG_NAME=''   # Name of the org to get all data from
GITHUB_PAT='' # Personal Access Token to used to gather data from GitHub

################################################################################
############################ FUNCTIONS #########################################
################################################################################
################################################################################
#### Function Header ###########################################################
Header()
{
  echo ""
  echo "######################################################"
  echo "######################################################"
  echo "############ GitHub Organization Archiver ############"
  echo "######################################################"
  echo "######################################################"
  echo ""

  ###########################################
  # Get the name of the GitHub Organization #
  ###########################################
  echo ""
  echo "------------------------------------------------------"
  echo "Please enter name of the GitHub Organization you wish to"
  echo "archive all repositories, followed by [ENTER]:"
  ########################
  # Read input from user #
  ########################
  read -r ORG_NAME
  # Clean any whitespace that may be enetered
  ORG_NAME_NO_WHITESPACE="$(echo -e "${ORG_NAME}" | tr -d '[:space:]')"
  ORG_NAME=$ORG_NAME_NO_WHITESPACE

  # Validate the Org Name
  if [ ${#ORG_NAME} -le 1 ]; then
    echo "Error! You must give a valid Orgainzation name!"
    exit 1
  fi

  ########################################
  # Get the GitHub Personal Access Token #
  ########################################
  echo ""
  echo "------------------------------------------------------"
  echo "Please enter the GitHub Personal Access Token used to gather and update"
  echo "information on your Organization, followed by [ENTER]:"
  echo "(note: your input will NOT be displayed)"
  ########################
  # Read input from user #
  ########################
  read -r -s GITHUB_PAT
  # Clean any whitespace that may be enetered
  GITHUB_PAT_NO_WHITESPACE="$(echo -e "${GITHUB_PAT}" | tr -d '[:space:]')"
  GITHUB_PAT=$GITHUB_PAT_NO_WHITESPACE
  ##########################################
  # Check the length of the PAT for sanity #
  ##########################################
  if [ ${#GITHUB_PAT} -ne 40 ]; then
    echo "GitHub PAT's are 40 characters in length! you gave me ${#GITHUB_PAT} characters!"
    if [ $DEBUG -eq 1 ]; then
      echo "DEBUG --- PAT:[$GITHUB_PAT]"
    fi
    exit 1
  fi

  ########################
  # Get the Dry-Run Flag #
  ########################
  # LEGEND:              #
  # 1=no archive         #
  # 0=archive            #
  ########################
  echo ""
  echo "------------------------------------------------------"
  echo "Would you like to run in DRY-RUN mode?"
  echo "This would show you what repositories would be archived before doing so."
  echo "It is IDEAL to run in DRY-RUN mode before you run fully."
  echo "(y)es (n)o, followed by [ENTER]:"
  ########################
  # Read input from user #
  ########################
  read -r DRY_RUN

  ##########################
  # Parse the DryRun Input #
  ##########################
  ParseDryRun "$DRY_RUN"

  #################
  # Header Prints #
  #################
  echo ""
  echo "------------------------------------------------------"
  echo "This script will ARCHIVE all repositories inside a GitHub Organization."
  echo "The GitHub Organization is set to: $ORG_NAME"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    echo "######################################################"
    echo "Script is in DRY-RUN mode! No repos will be archived"
    echo "Only repoting the actions that would be taken"
    echo "######################################################"
    echo ""
  else
    echo ""
    echo "######################################################"
    echo "WARNING! SCRIPT IS IN EXECUTE MODE!!!"
    echo "WE WILL BE ARCHIVING ALL REPOS INSIDE: $ORG_NAME"
    echo "######################################################"
    echo ""
  fi
}
################################################################################
#### Function ParseDryRun ######################################################
ParseDryRun()
{
  # We really need to let the user know this is super dangerous
  # And they should be 100% aware of the issues as they run this script

  ##############
  # Read input #
  ##############
  DRY_RUN=$1

  if [ $DEBUG -eq 1 ]; then
    echo "DEBUG --- DRY_RUN flag=[$DRY_RUN]"
  fi

  ######################
  # Dry-Run flag logic #
  ######################
  if [[ "$DRY_RUN" == "yes" ]] || [[ "$DRY_RUN" == "y" ]]; then
    echo "You have elected to run in DRY-RUN mode... Good choice..."
    DRY_RUN='1'
  else
    echo "SERIOUSLY... Are you going to archive all the repositoties inside:[$ORG_NAME]?"
    echo "There is no real going back on this..."
    echo ""
    echo ""
    echo "DO YOU WANT TO ARCHIVE ALL REPOSITORIES INSIDE:[$ORG_NAME]"
    echo "(y)es (n)o, followed by [ENTER]:"

    #######################
    # Read the user input #
    #######################
    read -r SAFETY_FLAG

    ######################
    # Validate the input #
    ######################
    if [[ "$SAFETY_FLAG" == "yes" ]] || [[ "$SAFETY_FLAG" == "y" ]]; then
      echo "You have elected to run in EXECUTE mode... God save the Queen..."
      DRY_RUN='0'
    else
      echo "You have elected to run in DRY-RUN mode... Good choice... Thank you for coming to your senses..."
      DRY_RUN='1'
    fi
  fi
  echo ""
}
################################################################################
#### Function Footer ###########################################################
Footer()
{
  #######################################
  # Basic footer information and totals #
  #######################################
  echo ""
  echo "######################################################"
  echo "The script has completed"
  echo "Total Repos parsed:[$TOTAL_REPO_COUNT]"
  echo "######################################################"
  echo ""
  echo ""
}
################################################################################
#### Function GetData ##########################################################
GetData()
{
  #######################
  # Debug To see cursor #
  #######################
  if [ $DEBUG -eq 1 ]; then
    echo "DEBUG --- End Cursor:[$END_CURSOR]"
  fi

  #####################################
  # Grab all the data from the system #
  #####################################
  DATA_BLOCK=$(curl -s -X POST -H "authorization: Bearer $GITHUB_PAT" -H "content-type: application/json" \
  --data "{\"query\":\"\nquery {\n organization(login: \\\"$ORG_NAME\\\") {\n repositories(first: $PAGE_SIZE, after: $END_CURSOR) {\n nodes {\n name\n }\n pageInfo {\n hasNextPage\n endCursor\n }\n }\n }\n}\"}" \
  "$GRAPHQL_URL" 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##########################
  # Check the shell return #
  ##########################
  if [ $ERROR_CODE -ne 0 ]; then
    echo "ERROR! Failed to gather data from GitHub!"
    exit 1
  fi

  #########################
  # DEBUG show data block #
  #########################
  if [ $DEBUG -eq 1 ]; then
    echo "DEBUG --- DATA BLOCK:[$DATA_BLOCK]"
  fi

  ##########################
  # Get the Next Page Flag #
  ##########################
  NEXT_PAGE=$(echo "$DATA_BLOCK" | jq .[] | jq -r '.organization.repositories.pageInfo.hasNextPage')
  if [ $DEBUG -eq 1 ]; then
    echo "DEBUG --- Next Page:[$NEXT_PAGE]"
  fi

  ##############################
  # Get the Current End Cursor #
  ##############################
  END_CURSOR=$(echo "$DATA_BLOCK" | jq .[] | jq -r '.organization.repositories.pageInfo.endCursor')
  if [ $DEBUG -eq 1 ]; then
    echo "DEBUG --- End Cursor:[$END_CURSOR]"
  fi

  #############################################
  # Parse all the repo data out of data block #
  #############################################
  ParseRepoData "$DATA_BLOCK"

  ########################################
  # See if we need to loop for more data #
  ########################################
  if [ "$NEXT_PAGE" == "false" ]; then
    # We have all the data, we can move on
    echo "Gathered all data from GitHub"
  elif [ "$NEXT_PAGE" == "true" ]; then
    # We need to loop through GitHub to get all repos
    echo "More pages of repos... Looping through data with new cursor:[$END_CURSOR]"
    ######################################
    # Call GetData again with new cursor #
    ######################################
    GetData
  else
    # Failing to get this value means we didnt get a good response back from GitHub
    # And it could be bad input from user, not enough access, or a bad token
    # Fail out and have user validate the info
    echo ""
    echo "######################################################"
    echo "ERROR! Failed response back from GitHub!"
    echo "Please validate your PAT, Organization, and access levels!"
    echo "######################################################"
    exit 1
  fi
}
################################################################################
#### Function ParseRepoData ####################################################
ParseRepoData()
{
  ##########################
  # Pull in the data block #
  ##########################
  PARSE_DATA=$1

  ####################################
  # Itterate through the json object #
  ####################################
  # We are only getting the repo names
  echo "Gathering Repository information..."
  for OBJECT in $(echo "$PARSE_DATA" | jq -r '.data.organization.repositories.nodes | .[] | .name' ); do
    #echo "RepoName:[$OBJECT]"
    TOTAL_REPO_COUNT=$((TOTAL_REPO_COUNT +1))
    ###############################
    # Push the repo names to aray #
    ###############################
    ORG_REPOS+=("$OBJECT")
  done
}
################################################################################
#### Function ValidateJQ #######################################################
ValidateJQ()
{
  # Need to validate the machine has jq installed as we use it to do the parsing
  # of all the json returns from GitHub

  ############################
  # See if it is in the path #
  ############################
  CHECK_JQ=$(command -v jq)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##########################
  # Check the shell return #
  ##########################
  if [ $ERROR_CODE -ne 0 ]; then
    echo "Failed to find jq in the path!"
    echo "ERROR:[$CHECK_JQ]"
    echo "If this is a Mac, run command: brew install jq"
    echo "If this is Debian, run command: sudo apt install jq"
    echo "If this is Centos, run command: yum install jq"
    echo "Once installed, please run this script again."
    exit 1
  fi
}
################################################################################
#### Function PerformArchive ###################################################
PerformArchive()
{
  #####################
  # Check for dry run #
  #####################
  if [ $DRY_RUN -eq 1 ]; then
    #################################################
    # This is DRY RUN and no repos will be archived #
    #################################################
    echo "------------------------------------------------------"
    echo "!!! DRY-RUN !!!"
    echo "We would archive the following repositories:"
    ###############################
    # Go through all repos in org #
    ###############################
    for REPO in "${ORG_REPOS[@]}"
    do
      echo "$REPO"
    done
  else
    #########################################
    # ARCHIVE all repos in the organization #
    #########################################
    echo "######################################################"
    echo "!!! WARNING !!! Prepared to archive:[$TOTAL_REPO_COUNT] repositories"
    echo "inside the GitHub Orgainzation:[$ORG_NAME]"
    echo "Are you sure you want to archive the repositories?"
    echo "(y)es (n)o, followed by [ENTER]:"
    ########################
    # Read input from user #
    ########################
    read -r SAFETY_FLAG

    ########################
    # Check the user input #
    ########################
    if [[ "$SAFETY_FLAG" == "yes" ]] || [[ "$SAFETY_FLAG" == "y" ]]; then
      echo "You asked for it... I shall deliver... Archiving all repositories..."

      for REPO_NAME in "${ORG_REPOS[@]}"
      do
        ##################
        # Create the URL #
        ##################
        ARCHIVE_URL="$GITHUB_API/v3/repos/$ORG_NAME/$REPO_NAME"

        ###################
        # Run the command #
        ###################
        ARCHIVE_CMD=$(curl -s -X PATCH -H "authorization: Bearer $GITHUB_PAT" \
        -H 'content-type: application/json' \
        -H 'accept: application/vnd.github.mercy-preview+json' \
        --data "{\"name\":\"$REPO_NAME\",\"archived\": true }" \
        "$ARCHIVE_URL" 2>&1)

        #######################
        # Load the error code #
        #######################
        ERROR_CODE=$?

        ##############
        # Debug info #
        ##############
        if [ $DEBUG -eq 1 ]; then
          echo "DEBUG --- ARCHIVE_CMD result:[$ARCHIVE_CMD]"
        fi

        ##########################
        # Check the shell return #
        ##########################
        if [ $ERROR_CODE -ne 0 ]; then
          echo "ERROR! Failed to Archive $REPO_NAME in GitHub!"
          exit 1
        else
          echo "Archived:[$REPO_NAME]"
        fi
      done
    fi
  fi
}
################################################################################
############################## MAIN ############################################
################################################################################

##########
# Header #
##########
Header

#########################
# Validate JQ installed #
#########################
ValidateJQ

###################
# Get GitHub Data #
###################
echo "------------------------------------------------------"
echo "Calling GitHub for data..."
GetData

######################
# Perform The Action #
######################
PerformArchive

##########
# Footer #
##########
Footer
