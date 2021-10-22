#!/bin/bash

GRAPHQL_URL='https://api.github.com/graphql'  # URL endpoint to graphql
ORG_NAME=$1
PAGE_SIZE=100           # Default is 100, GitHub limit is 100
END_CURSOR='null'       # Set to null, will be updated after call
DEBUG=0                 # 0=Debug OFF | 1=Debug ON

##############
# USER INPUT #
##############

ORG_NAME=$1   # Name of the org to get all data from
GITHUB_PAT=$2 # Personal Access Token to used to gather data from GitHub

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
  echo "############# GitHub repo list and sizer #############"
  echo "######################################################"
  echo "######################################################"
  echo ""

  ###########################################
  # Get the name of the GitHub Organization #
  ###########################################
  # Validate the Org Name
  if [ ${#ORG_NAME} -le 1 ]; then
    echo "Error! You must give a valid Orgainzation name!"
    exit 1
  fi

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

  #################
  # Header Prints #
  #################
  echo ""
  echo "------------------------------------------------------"
  echo "This script will generate a .csv file that contains a list of all"
  echo "repositories inside the GitHub Organization: $ORG_NAME"
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
  echo "Total size of Organization on Disk:[$TOTAL_DISK_USAGE_MB]mb"
  echo "Total Repos found in $ORG_NAME:[$TOTAL_REPO_COUNT]"
  echo "Results file:[$FILE_NAME]"
  echo "######################################################"
  echo ""
  echo ""
}
################################################################################
#### Function GenerateFile #####################################################
GenerateFile()
{
  ####################
  # Create File Name #
  ####################
  FILE_NAME="repositories.csv"

  ##########################
  # Create the in use file #
  ##########################
  # Validate we can write file
  CREATE_FILE=$(touch "$FILE_NAME")

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##########################
  # Check the shell return #
  ##########################
  if [ $ERROR_CODE -ne 0 ]; then
    echo "Failed to generate result file: $FILE_NAME!"
    echo "ERROR:[$CREATE_FILE]"
    exit 1
  fi
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
  # Grab all the data from the org    #
  #####################################
  if [ "$END_CURSOR" = null ]; then
    QUERY="{\"query\":\"query { \n organization(login: \\\"$ORG_NAME\\\") {\n repositories(first: $PAGE_SIZE) {\n nodes\n {\n name \n }\n pageInfo {\n hasNextPage\n endCursor\n }\n }\n }\n}\n\"}"
  else
    QUERY="{\"query\":\"query { \n organization(login: \\\"$ORG_NAME\\\") {\n repositories(first: $PAGE_SIZE, after: \\\"$END_CURSOR\\\") {\n nodes\n {\n name \n }\n pageInfo {\n hasNextPage\n endCursor\n }\n }\n }\n}\n\"}"
  fi
  DATA_BLOCK=$(curl -s -X POST -H "authorization: Bearer $GITHUB_PAT" -H "content-type: application/json" \
  --data  "$QUERY" \
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
  # Iterate through the json object #
  ####################################
  # We are only getting the repo names
  echo "Adding Organization/Repositories to results file..."
  for OBJECT in $(echo "$PARSE_DATA" | jq -r '.data.organization.repositories.nodes | .[] | .name' ); do
    echo "RepoName:[$OBJECT]"
    ######################################
    # Push the repo names to Result File #
    ######################################
    echo "$OBJECT" >> "$FILE_NAME"
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
############################## MAIN ############################################
################################################################################

##########
# Header #
##########
Header

##########################
## Validate JQ installed #
##########################
ValidateJQ

##################
## Generate File #
##################
GenerateFile

####################
## Get GitHub Data #
####################
echo "------------------------------------------------------"
echo "Calling GitHub for data..."
GetData

###########
## Footer #
###########
Footer
