#!/bin/bash -x
################################################################################
################################################################################
####### Update default branch @AdmiralAwkbar ####################################
################################################################################
################################################################################

# LEGEND:
# This script will use the GitHub API to update the default branch
# of all repositories that are listed in the .csv provided
#
# PREREQS:
# You will need a GitHub Personal Access token to query the api
#
# HOW To Run:
# - Copy file to local machine
# - chmod +x file.sh
# - ./file.sh
# - pass the file input that is requested
#

###########
# GLOBALS #
###########
GITHUB_URL='https://api.github.com' # URL for GitHub
CLEAN_FILE='/tmp/clean_file.txt'    # Clean version of the file
REPOS_UPDATED=0                     # Count of repos updated
DEBUG=0                             # 0=Debug OFF | 1=Debug ON

##############
# USER INPUT #
##############
DATA_FILE='repositories.csv'    # File with all the repos and branches to update
ORG_NAME="$1"
GITHUB_PAT="$2"

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
  echo "###### GitHub update default branch of repo(s) #######"
  echo "######################################################"
  echo "######################################################"
  echo ""

  ##########################
  # Get the File with data #
  ##########################
  echo ""
  echo "------------------------------------------------------"
  echo "Please enter the full path and name to the file that holds the name of all repos"
  echo "and their new default branch, followed by [ENTER]:"
  echo "(Note: The branch must already exist on the repository)"
  echo "(Note: File format should be:)"
  echo "OrgName/RepoName/branchName"
  echo "OrgName1/RepoName1/branchName1"
  echo "..."
  echo ""

  #####################
  # Validate the file #
  #####################
  # Check location and size
  if [ ! -s "$DATA_FILE" ]; then
    # Error
    echo "ERROR! Could NOT find file at:[$DATA_FILE] or it is empty!"
    echo "Please check input and location!"
    echo "------------------------------------------------------"
    echo ""
    exit 1
  else
    # Success
    echo "Successfully found file at:[$DATA_FILE]"
    echo "------------------------------------------------------"
    echo ""
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
  else
    echo "GitHub PAT seems to meet basic qualifications..."
    echo "------------------------------------------------------"
    echo ""
  fi

  ##############################
  # Get the create branch flag #
  ##############################
  #  echo ""
  #  echo "------------------------------------------------------"
  #  echo "If the new default branch does not exist, would you"
  #  echo "want it created, and based off 'master(default)'?"
  #  echo "type '(y)es' to create or '(n)o' followed by [ENTER]:"
  ########################
  # Read input from user #
  ########################
  #  read -r CREATE_BRANCH_FLAG
  CREATE_BRANCH_FLAG="y"

  ###########################
  # Validate the user input #
  ###########################
  if [[ "$CREATE_BRANCH_FLAG" == "yes" ]] || [[ "$CREATE_BRANCH_FLAG" == "y" ]] || \
    [[ "$CREATE_BRANCH_FLAG" == "Y" ]] || [[ "$CREATE_BRANCH_FLAG" == "YES" ]]; then

    ############################
    # Were creating the branch #
    ############################
    echo "- User has elected to create a branch off of master if not found..."
    CREATE_BRANCH_FLAG=1
  else
    ##################################
    # Not going to create the branch #
    ##################################
    CREATE_BRANCH_FLAG=0
    echo "- User has elected NOT to create the branch if it does not exist"
  fi

  #########################
  # Prints for GitHub.com #
  #########################
  echo ""
  echo "------------------------------------------------------"
  echo "This script will use the GitHub API to connect to:[$GITHUB_URL]"
  echo "and update the list of repo(s) to have the default branch updated."
  echo ""
  echo "------------------------------------------------------"
  echo ""
}
################################################################################
#### Function CleanDataFile ####################################################
CleanDataFile()
{
  # We are going to remove all empty lines from the file
  # To make sure we dont hit any bad data
  # Using grep instead of sed as sed works differnt on diff operating systems

  #######################
  # Write to clean file #
  #######################
  CLEAN_FILE_CMD=$(rm -f "$CLEAN_FILE"; grep -v '^$' "$DATA_FILE" > "$CLEAN_FILE" 2>&1)

  ###################
  # Load error code #
  ###################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    # Error
    echo "ERROR! Failed to clean file!"
    echo "ERROR:[$CLEAN_FILE_CMD]"
    exit 1
  fi

  ########################################
  # Write the file back to the real file #
  ########################################
  MV_FILE_CMD=$(mv "$CLEAN_FILE" "$DATA_FILE" 2>&1)

  ###################
  # Load error code #
  ###################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    # Error
    echo "ERROR! Failed to move clean file into place!"
    echo "ERROR:[$MV_FILE_CMD]"
    exit 1
  fi
}
################################################################################
#### Function CreateRepoBranch #################################################
CreateRepoBranch()
{
  #########################
  # Pull in the variables #
  #########################
  ORG_NAME=$1     # Name of the GitHub Org
  REPO_NAME=$2    # Name of the GitHub repo
  BRANCH_NAME=$3  # Name of the GitHub branch
  SHA=''          # Git SHA of the GitHub master branch

  ###############################################################
  # Need to get the SHA for the master branch to build a branch #
  ###############################################################
  GET_SHA_CMD=$(curl -s -k -X GET \
    --url "$GITHUB_URL/repos/$ORG_NAME/$REPO_NAME/git/refs/heads/master" \
    -H 'accept: application/vnd.github.mercy-preview+json' \
    -H "authorization: Bearer $GITHUB_PAT" \
    -H 'content-type: application/json' | jq .object.sha 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    # Error
    echo "ERROR! Failed to get SHA for branch:[master] on:[$ORG_NAME/$REPO_NAME]"
    exit 1
  else
    ###############
    # Set the SHA #
    ###############
    SHA="$GET_SHA_CMD"

    ##########################
    # Validate if has length #
    ##########################
    if [ -z "$SHA" ]; then
      # ERROR
      echo "ERROR! Failed to get SHAx from master of:[$ORG_NAME/$REPO_NAME]"
      echo "ERROR:[$GET_SHA_CMD]"
      exit 1
    fi
  fi

  ##############################################
  # Create the branch with the sha from master #
  ##############################################
  CREATE_BRANCH_CMD=$(curl -s -k -X POST \
    --url "$GITHUB_URL/repos/$ORG_NAME/$REPO_NAME/git/refs" \
    -H 'accept: application/vnd.github.mercy-preview+json' \
    -H "authorization: Bearer $GITHUB_PAT" \
    -H 'content-type: application/json' \
    -d '{ "ref": "'"refs/heads/$BRANCH_NAME"'", "sha": '"$SHA"'}' 2>&1)

  #######################
  # Load the error code #
  #######################
  ERROR_CODE=$?

  ##############################
  # Check the shell for errors #
  ##############################
  if [ $ERROR_CODE -ne 0 ]; then
    # Error
    echo "WARN! Creation of branch:[$BRANCH_NAME] of:[$ORG_NAME/$REPO_NAME] failed!"
    echo "WARN:[$CREATE_BRANCH_CMD]"
  else
    # Success
    echo "Success! Created branch:[$BRANCH_NAME] of:[$ORG_NAME/$REPO_NAME]"
  fi
}
################################################################################
#### Function UpdateRepos ######################################################
UpdateRepos()
{
  ################################################
  # Read the DATA_FILE line by line to pull data #
  ################################################
  while IFS= read -r LINE;
  do
    echo "-------------------------------------------"
    ############################################
    # Clean any whitespace that may be entered #
    ############################################
    LINE_NO_WHITESPACE="$(echo "${LINE}" | tr -d '[:space:]')"
    LINE="$LINE_NO_WHITESPACE"

    #######################
    # Split the variables #
    #######################
    REPO_NAME="$LINE"
    BRANCH_NAME="main"

    ######################################
    # Validate we have all the variables #
    ######################################
    if [ -z "$ORG_NAME" ] || [ -z "$REPO_NAME" ] || [ -z "$BRANCH_NAME" ]; then
      # One of these is empty!
      echo "ERROR! Failed to find all needed data in line:[$LINE]!"
      echo "ERROR! Please validate:[$DATA_FILE] has all needed information!"
      exit 1
    fi

    ##############
    # Debug info #
    ##############
    if [ $DEBUG -ne 0 ]; then
      echo "--- DEBUG --- Line:[$LINE]"
      echo "--- DEBUG --- ORG_NAME:[$ORG_NAME]"
      echo "--- DEBUG --- REPO_NAME:[$REPO_NAME]"
      echo "--- DEBUG --- BRANCH_NAME:[$BRANCH_NAME]"
    fi

    ################################
    # Create the branch if elected #
    ################################
    if [ $CREATE_BRANCH_FLAG -eq 1 ]; then
      # Create the branch
      CreateRepoBranch "$ORG_NAME" "$REPO_NAME" "$BRANCH_NAME"
    fi

    #################
    # Print headers #
    #################
    echo "Updating:[$ORG_NAME/$REPO_NAME] with default branch:[$BRANCH_NAME]..."

    #########################################
    # Call API to update the default branch #
    #########################################
    UPDATE_BRANCH_CMD=$(curl -s -k -X PATCH \
      --url "$GITHUB_URL/repos/$ORG_NAME/$REPO_NAME" \
      -H 'accept: application/vnd.github.mercy-preview+json' \
      -H 'content-type: application/json' \
      -H "authorization: Bearer $GITHUB_PAT" \
      -d "{ \"default_branch\": \"$BRANCH_NAME\" }" 2>&1)

    #######################
    # Load the error code #
    #######################
    ERROR_CODE=$?

    ##############
    # Debug info #
    ##############
    if [ $DEBUG -ne 0 ]; then
      # Debug info
      echo "--- DEBUG --- Info:[$UPDATE_BRANCH_CMD]"
      echo "--- DEBUG --- ErrorCode:[$ERROR_CODE]"
    fi

    ##############################
    # Check the shell for errors #
    ##############################
    if [ $ERROR_CODE -ne 0 ]; then
      # Error
      echo " - ERROR! Failed to update default branch:[$BRANCH_NAME] on:[$ORG_NAME/$REPO_NAME]!"
      echo " - ERROR:[$UPDATE_BRANCH_CMD]"
      exit 1
    else
      # Success
      echo " - Successfully set default branch:[$BRANCH_NAME] on:[$ORG_NAME/$REPO_NAME]"
      ######################
      # Update the counter #
      ######################
      ((REPOS_UPDATED++))
    fi
  done < "$DATA_FILE"
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
  echo "Count of repositories with updated default branch:[$REPOS_UPDATED]"
  echo "######################################################"
  echo ""
}
################################################################################
############################## MAIN ############################################
################################################################################

##########
# Header #
##########
Header

#######################
# Clean the data file #
#######################
CleanDataFile

########################
# Update all the repos #
########################
UpdateRepos

##########
# Footer #
##########
Footer
