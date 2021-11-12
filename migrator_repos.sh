#!/bin/bash

### SET THIS VARIABLES

SOURCE_ORGANIZATION=YOUR_SOURCE_ORG
DESTINATION_ORGANIZATION=YOUR_DESTINATION_ORG
PAT=YOUR_PAT

### END VARIABLE SECTION

echo -e "Setting up the environment..."
echo -e "  Installing jq... \n"
sudo apt install jq

#Read the repos file
sed -i 's/\r//' repos.txt
mapfile REPOS < repos.txt

echo "  Loaded ${#REPOS[@]} Repos"
echo ${REPOS[*]}

#Read the team mappings file
declare -A TEAM_MAPPINGS

sed -i 's/\r//' team_mapping.txt
readarray -t lines < team_mapping.txt
for line in "${lines[@]}"
do
   key=${line%=*}
   value=${line#*=}
   TEAM_MAPPINGS[$key]=$value 
done

echo "  Loaded ${#TEAM_MAPPINGS[@]} Mapped Teams"
HEADERS=(-H "Accept: application/vnd.github.v3+json" -H "Authorization: token $PAT")

# Get the Teams for each repo

for repo in ${REPOS[*]}
do
    echo -e "\nProcessing $SOURCE_ORGANIZATION/$repo ...\n"
    echo -e "  Retrieving the Teams"

    APIURL="https://api.github.com/repos/$SOURCE_ORGANIZATION/$repo/teams"
    TEAMSJSON=$(curl -s "${HEADERS[@]}" $APIURL)

    TEAMS=($(jq -r '.[].name' <<< $TEAMSJSON | tr -d '[]," '))
    ROLES=($(jq -r '.[].permission' <<< $TEAMSJSON | tr -d '[]," '))

    echo -e "  Found ${#TEAMS[@]} Teams\n"
    echo Teams: ${TEAMS[*]}
    echo Roles: ${ROLES[*]}

    # Maps the old teams with the new teams and assigns the permissions
    echo -e "  \nBuilding the permissions\n"

    declare -A TEAMS_WITH_ROLES
    declare -A NEW_TEAMS_WITH_ROLES
    for i in $( seq 1 ${#TEAMS[@]} )
    do
      TEAMS_WITH_ROLES[${TEAMS[i - 1]}]=${ROLES[i - 1]}
      NEW_TEAM=${TEAM_MAPPINGS[${TEAMS[i - 1]}]}
      echo Old Team: ${TEAMS[i - 1]}
      echo New Team: $NEW_TEAM
      [[ -z "$NEW_TEAM" ]] && echo "WARNING: Team mapping not found for ${TEAMS[i - 1]}" || NEW_TEAMS_WITH_ROLES[$NEW_TEAM]=${ROLES[i - 1]}      
    done
    
    echo Old Teams and Roles:
    for to in "${!TEAMS_WITH_ROLES[@]}"
    do
        echo "  $to = ${TEAMS_WITH_ROLES[$to]}"
    done

    echo New Teams and Roles:
    for tn in "${!NEW_TEAMS_WITH_ROLES[@]}"
    do
        echo "  $tn = ${NEW_TEAMS_WITH_ROLES[$tn]}"
    done

    # Assigns the teams with the proper permissions to the repos in the new org
    echo -e "  \nMigrating the permissions\n"

    for team in "${!NEW_TEAMS_WITH_ROLES[@]}"
    do
        APIURL="https://api.github.com/orgs/$DESTINATION_ORGANIZATION/teams/$team/repos/$DESTINATION_ORGANIZATION/$repo"
        $(curl -X PUT "${HEADERS[@]}" $APIURL -d "{\"permission\":\"${NEW_TEAMS_WITH_ROLES[$team]}\"}")
    done
done

echo "DONE!"