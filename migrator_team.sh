#!/bin/bash

### SET THIS VARIABLES!

TEAM_NAME=YOUR_TEAM_NAME
SOURCE_ORGANIZATION=YOUR_SOURCE_ORG
DESTINATION_ORGANIZATION=YOUR_DESTINATION_ORG
PAT=YOUR_PAT

### END VARIABLE SECTION

echo -e "Setting up the environment..."
echo -e "  Installing jq... \n"
sudo apt install jq

HEADERS=(-H "Accept: application/vnd.github.v3+json" -H "Authorization: token $PAT")

# Get the Repos of the team

echo -e "\nRetrieving the Teams and Permissions from the Org: $SOURCE_ORGANIZATION...\n"

APIURL="https://api.github.com/orgs/$SOURCE_ORGANIZATION/teams/$TEAM_NAME/repos"

REPOSJSON=$(curl -s "${HEADERS[@]}" $APIURL)

REPOS=($(jq -r '.[].name' <<< $REPOSJSON | tr -d '[]," '))
ROLES=($(jq -r '.[].role_name' <<< $REPOSJSON | tr -d '[]," '))

echo -e "\nGot ${#REPOS[@]} repos:"

declare -A ReposWithRoles

for i in $( seq 1 ${#REPOS[@]} )
do
    ReposWithRoles[${REPOS[i - 1]}]=${ROLES[i - 1]}
done

for repo in "${!ReposWithRoles[@]}"
do
    echo "  $repo = ${ReposWithRoles[$repo]}"
done


echo -e "\nSetting Permissions for the Team in the Org: $DESTINATION_ORGANIZATION...\n"

for repo in "${!ReposWithRoles[@]}"
do
    APIURL="https://api.github.com/orgs/$DESTINATION_ORGANIZATION/teams/$TEAM_NAME/repos/$DESTINATION_ORGANIZATION/$repo"
    $(curl -X PUT "${HEADERS[@]}" $APIURL -d "{\"permission\":\"${ReposWithRoles[$repo]}\"}")    
done 

echo "DONE!"