#!/bin/bash

# run.sh: interactively receive and store the configuration for backup/restore
#
# Author: Fernando Sanchez [ fernando at mesosphere.com ]
#
# This set of scripts allows to backup and restore several configurations from
# a running DC/OS Cluster. It uses the DC/OS REST API as Documented here:
# https://docs.mesosphere.com/1.8/administration/id-and-access-mgt/iam-api/
#
# A $PWD/DATA directory is created to store all information backed up from the cluster
# All files in this DATA directory are encoded in raw JSON. The restore scripts read
# these files, extract the relevant fields and post them back to the clister

# This first "run.sh" script initializes the cluster, interactively reads the 
# configuration and saves it in JSON format to a fixed, well known location in $PWD
# hidden  under .config.json

#load environment variables
source ./env.sh

function load_configuration {
#read configuration if it exists
#config is stored directly on JSON format
if [ -f $CONFIG_FILE ]; then

	DCOS_IP=$(cat $CONFIG_FILE | jq -r '.DCOS_IP')
	USERNAME=$(cat $CONFIG_FILE | jq -r '.USERNAME')
	PASSWORD=$(cat $CONFIG_FILE | jq -r '.PASSWORD')
	DEFAULT_USER_PASSWORD=$(cat $CONFIG_FILE | jq -r '.DEFAULT_USER_PASSWORD')
	DEFAULT_USER_SECRET=$(cat $CONFIG_FILE | jq -r '.DEFAULT_USER_SECRET')
	WORKING_DIR=$(cat $CONFIG_FILE | jq -r '.WORKING_DIR')
	CONFIG_FILE=$(cat $CONFIG_FILE | jq -r '.CONFIG_FILE')
	USERS_FILE=$(cat $CONFIG_FILE | jq -r '.USERS_FILE')
	USERS_GROUPS_FILE=$(cat $CONFIG_FILE | jq -r '.USERS_GROUPS_FILE')	
	GROUPS_FILE=$(cat $CONFIG_FILE | jq -r '.GROUPS_FILE')
	GROUPS_USERS_FILE=$(cat $CONFIG_FILE | jq -r '.GROUPS_USERS_FILE')
	ACLS_FILE=$(cat $CONFIG_FILE | jq -r '.ACLS_FILE')
	ACLS_PERMISSIONS_FILE=$(cat $CONFIG_FILE | jq -r '.ACLS_PERMISSIONS_FILE')

else
	$CLS
	echo -e "** ${BLUE}WARNING${NC}: Configuration not found. "
	echo -e "** This is normal if this is the first time this program is run in this system."
	echo -e "** Generating a new configuration."
	read -p "Press ENTER to continue."
fi
}

function show_configuration {
#show the currently running configuration
#TODO: reformat
	echo "** DEBUG: Current configuration: "
	cat $CONFIG_FILE | jq
}

#install dependencies

JQ="jq"

if [ ! $JQ ]; then 

	read -p "** ${RED}ERROR${NC} JQ is not available but it's required. Please install $JQ in your system, then re-run this application"
	exit 1

fi

load_configuration

while true; do
	$CLS
	echo ""
	echo -e "** Current parameters:"
	echo -e ""
	echo -e "*************************                 ****************"
	echo -e "${BLUE}1${NC}) DC/OS IP or DNS name:                  "${RED}$DCOS_IP${NC}
	echo -e "*************************                 ****************"
	echo -e "${BLUE}2${NC}) DC/OS username:                        "${RED}$USERNAME${NC}
	echo -e "${BLUE}3${NC}) DC/OS password:                        "${RED}$PASSWORD${NC}
	echo -e "${BLUE}4${NC}) Default password for restored users:   "${RED}$DEFAULT_USER_PASSWORD${NC}
	echo -e ""
	echo -e "${BLUE}INFO${NC}: Local buffer location:		"${RED}$DATA_DIR${NC}

	echo ""
	
	read -p "** Are these parameters correct?: (y/n): " REPLY

		case $REPLY in
			
			[yY]) echo ""
				echo "** Proceeding."
				break
				;;
			
			[nN]) read -p "** Enter parameter to modify [1-4]: " PARAMETER

				case $PARAMETER in

					[1]) read -p "Enter new value for DC/OS IP or DNS name: " DCOS_IP
					;;
					[2]) read -p "Enter new value for DC/OS username: " USERNAME
					;;
					[3]) read -p "Enter new value for DC/OS password: " PASSWORD
					;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input. Please choose a valid option"
						read -p "Press ENTER to continue"
					;;

				esac
				;;
			*) echo -e "** ${RED}ERROR${NC}: Invalid input. Please choose [y] or [n]"
			read -p "Press ENTER to continue"
			;;
	
		esac

done

#get token from cluster
TOKEN=$( curl \
-H "Content-Type:application/json" \
--data '{ "uid":"'"$USERNAME"'", "password":"'"$PASSWORD"'" }' \
-X POST \
http://$DCOS_IP/acs/api/v1/auth/login \
| jq -r '.token' )

#create working dir
mkdir -p $WORKING_DIR

#save configuration to config file in working dir
CONFIG="\
{ \
"\"DCOS_IP"\": "\"$DCOS_IP"\",   \
"\"USERNAME"\": "\"$USERNAME"\", \
"\"PASSWORD"\": "\"$PASSWORD"\", \
"\"DEFAULT_USER_PASSWORD"\": "\"$DEFAULT_USER_PASSWORD"\", \
"\"DEFAULT_USER_SECRET"\": "\"$DEFAULT_USER_SECRET"\", \
"\"WORKING_DIR"\": "\"$WORKING_DIR"\", \
"\"CONFIG_FILE"\": "\"$CONFIG_FILE"\",  \
"\"USERS_FILE"\": "\"$USERS_FILE"\",  \
"\"USERS_GROUPS_FILE"\": "\"$USERS_GROUPS_FILE"\",  \
"\"GROUPS_FILE"\": "\"$GROUPS_FILE"\",  \
"\"GROUPS_USERS_FILE"\": "\"$GROUPS_USERS_FILE"\",  \
"\"ACLS_FILE"\": "\"$ACLS_FILE"\",  \
"\"ACLS_PERMISSIONS_FILE"\": "\"$ACLS_PERMISSIONS_FILE"\",  \
"\"TOKEN"\": "\"$TOKEN"\"  \
} \
"

#save config to file for future use
echo $CONFIG > $CONFIG_FILE
show_configuration

#DEBUG: export them all for CLI debug
echo "** Exporting env variables"
export DCOS_IP=$DCOS_IP
export USERNAME=$USERNAME
export PASSWORD=$PASSWORD
export DEFAULT_USER_SECRET=$DEFAULT_USER_SECRET
export DEFAULT_USER_PASSWORD=$DEFAULT_USER_PASSWORD
export WORKING_DIR=$WORKING_DIR
export CONFIG_FILE=$CONFIG_FILE
export USERS_FILE=$USERS_FILE
export USERS_GROUPS_FILE=$USERS_GROUPS_FILE
export GROUPS_FILE=$GROUPS_FILE
export GROUPS_USERS_FILE=$GROUPS_USERS_FILE
export ACLS_FILE=$ACLS_FILE
export ACLS_PERMISSIONS_FILE=$ACLS_PERMISSIONS_FILE
export TOKEN=$TOKEN

read -p "Press ENTER to continue"

while true; do
	$CLS
	echo -e ""
	echo -e "** DC/OS Config Backup and Restore Utility:"
	echo -e "*****************************************************************"
	echo -e "** Operations to retrieve configuration from a running cluster:"
	echo -e "**"
	echo -e "${BLUE}1${NC}) Get users from DC/OS to local buffer:		"$GET_USERS_OK
	echo -e "${BLUE}2${NC}) Get groups from DC/OS to local buffer:		"$GET_GROUPS_OK
	echo -e "${BLUE}3${NC}) Get ACLs from DC/OS to local buffer:			"$GET_ACLS_OK
	echo -e "*****************************************************************"
	echo -e "** Operations to restore backed up configuration to a running cluster:"
	echo -e "**"
	echo -e "${BLUE}4${NC}) Restore users to DC/OS from local buffer:		"$POST_USERS_OK
	echo -e "${BLUE}5${NC}) Restore groups to DC/OS from local buffer:		"$POST_GROUPS_OK
	echo -e "${BLUE}6${NC}) Restore ACLs to DC/OS from local buffer:		"$POST_ACLS_OK
	echo -e "*****************************************************************"
	echo -e "** Operations to check out currently buffered configuration:"
	echo -e "**"
	echo -e "${BLUE}7${NC}) Check users currently in local buffer.                  		"
	echo -e "${BLUE}8${NC}) Check groups currently in local buffer.	                    	"
	echo -e "${BLUE}9${NC}) Check ACLs currently in local buffer.	                        "
	echo -e "${BLUE}0${NC}) Check current configuration.                  		"
	echo -e ""
	echo -e "*****************************************************************"
	echo -e "** Operations to save/load configurations to/from disk:"
	echo -e "**"
	echo -e "${BLUE}d${NC}) List configurations currently available on disk "
	echo -e "${BLUE}l${NC}) Load a configuration from disk                  	"
	echo -e "${BLUE}s${NC}) Save current local buffer status to disk                  		"
	echo -e "*****************************************************************"
	echo -e "** DEBUG operations:"
	echo -e "**"
	echo -e "${BLUE}z${NC}) Restore EXAMPLE configuration for test.              		"
	echo -e "*****************************************************************"
	echo -e "${BLUE}x${NC}) Exit this application"
	echo ""
	
	read -p "** Enter command: " PARAMETER

		case $PARAMETER in

			[1]) echo -e "** About to get the list of Users in DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				echo -e "** to local buffer [ "${RED}$USERS_FILE${NC}" ]"
				read -p "Confirm? (y/n)" $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						bash $GET_USERS
						read -p "Press ENTER to continue..."
						#TODO: validate result
						GET_USERS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input."
						read -p "Please choose [y] or [n]"
						;;
				esac
			;;	
			[2]) echo -e "** About to get the list of Groups in DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				echo -e "** to local buffer [ "${RED}$GROUPS_FILE${NC}" ]"
				echo -e "** About to get the list of User/Group memberships in DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				echo -e "** to local buffer [ "${RED}$GROUPS_USERS_FILE${NC}" ]"
				read -p "Confirm? (y/n)" $REPLY
		
				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						bash $GET_GROUPS
						read -p "Press ENTER to continue..."
						#TODO: validate result
						GET_GROUPS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) read -p "** ${RED}ERROR${NC}: Invalid input. Please choose [y] or [n]"
						;;

				esac
			;;	
			[3]) echo -e "** About to get the list of ACLs in DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				echo -e "** to buffer [ "${RED}$ACLS_FILE${NC}" ]"
				read -p "Confirm? (y/n)" $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						bash $GET_ACLS
						read -p "Press ENTER to continue..."
						#TODO: validate result
						GET_ACLS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input."
						read -p "Please choose [y] or [n]"
						;;
				esac
			;;	
			[4]) echo -e "** About to restore the list of Users in local buffer [ "${RED}$USERS_FILE${NC}" ]"
				echo -e "** to DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				read -p "Confirm? (y/n)" $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						bash $POST_USERS
						read -p "Press ENTER to continue..."
						#TODO: validate result
						POST_USERS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input."
						read -p "Please choose [y] or [n]"
						;;
				esac
			;;	
			[5]) echo -e "** About to restore the list of Groups in buffer [ "${RED}$USERS_FILE${NC}" ]"
				echo -e "** and the list of User/Group permissions in buffer [ "${RED}$GROUPS_USERS_FILE${NC}" ]"
				echo -e "** to DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				read -p "Confirm? (y/n)" $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						bash $POST_GROUPS
						read -p "Press ENTER to continue..."
						#TODO: validate result
						POST_GROUPS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input."
						read -p "Please choose [y] or [n]"
						;;
				esac
			;;	
			[6]) echo -e "** About to restore the list of ACLs in buffer [ "${RED}$ACLS_FILE${NC}" ]"
				echo -e "** to DC/OS [ "${RED}$DCOS_IP${NC}" ]"
				read -p "Confirm? (y/n)" $REPLY

				case $REPLY in

					[yY]) echo ""
						echo "** Proceeding."
						bash $POST_ACLS
						read -p "Press ENTER to continue..."
						#TODO: validate result
						POST_ACLS_OK=$PASS
						;;
					[nN]) echo ""
						echo "** Cancelled."
						sleep 1
						;;
					*) echo -e "** ${RED}ERROR${NC}: Invalid input."
						read -p "Please choose [y] or [n]"
						;;
				esac
			;;	
			[7]) echo -e "** Stored Users information on buffer [ "${RED}$USERS_FILE${NC}" ] is:"
				cat $USERS_FILE | jq '.array'
				read -p "Press ENTER to continue"
			;;
			[8]) echo -e "** Stored Groups information on buffer [ "${RED}$GROUPS_FILE${NC}" ] is:"
				cat $GROUPS_FILE | jq '.array'
				echo -e "** Stored Group/User memberships information on file [ "${RED}$GROUPS_USERS_FILE${NC}" ] is:"
				cat $GROUPS_USERS_FILE | jq '.array'
				read -p "Press ENTER to continue"
			;;
			[9]) echo -e "** Stored ACLs information on buffer [ "${RED}$ACLS_FILE${NC}" ] is:"
				cat $ACLS_FILE | jq '.array'
				echo -e "** Stored ACL/Group association information on file [ "${RED}$ACLS_GROUPS_FILE${NC}" ] is:"
				cat $ACLS_GROUPS_FILE | jq '.array'
				echo -e "** Stored ACL/User association information on file [ "${RED}$ACLS_USERS_FILE${NC}" ] is:"
				cat $ACLS_USERS_FILE | jq '.array'					
				read -p "Press ENTER to continue"
			;;
			[0]) echo -e "** Configuration currently in buffer [ "${RED}$CONFIG_FILE${NC}" ] is:"
				show_configuration
				read -p "Press ENTER to continue"
			;;	
			[dD]) echo -e "** Currently available configurations:"
				ls -A1l $BACKUP_DIR | grep ^d | awk '{print $9}' 
				read -p "Press ENTER to continue"
			;;
			[lL]) ls -A1l $BACKUP_DIR | grep ^d | awk '{print $9}'
				echo -e "${BLUE}WARNING${NC}: Currently local buffer will be OVERWRITTEN)"
				read -p "** Please enter the name of a saved buffered to load. " ID
				#TODO: check that it actually exists
				cp $BACKUP_DIR/$ID/$( basename $USERS_FILE )  $USERS_FILE
				cp $BACKUP_DIR/$ID/$( basename $USERS_GROUPS_FILE ) $USERS_GROUPS_FILE
				cp $BACKUP_DIR/$ID/$( basename $GROUPS_FILE ) $GROUPS_FILE				
				cp $BACKUP_DIR/$ID/$( basename $GROUPS_USERS_FILE )_FILE	$GROUPS_USERS_FILE 
				cp $BACKUP_DIR/$ID/$( basename $ACLS_FILE ) $ACLS_FILE 
				cp $BACKUP_DIR/$ID/$( basename $ACLS_PERMISSIONS_FILE ) $ACLS_PERMISSIONS_FILE  
				load_configuration
			;;
			[sS]) echo -e "${BLUE}WARNING${NC}: If a configuration under this name exists, it will be OVERWRITTEN)" 
				read -p "** Please enter a name to save under: "ID
				#TODO: check if it exists and fail if it does
				mkdir -p $BACKUP_DIR/$ID/
				cp $USERS_FILE $BACKUP_DIR/$ID/
				cp USERS_GROUPS_FILE $BACKUP_DIR/$ID/
				cp $GROUPS_FILE $BACKUP_DIR/$ID/				
				cp $GROUPS_USERS_FILE $BACKUP_DIR/$ID/	
				cp $ACLS_FILE $BACKUP_DIR/$ID/
				cp $ACLS_PERMISSIONS_FILE $BACKUP_DIR/$ID/		
				cp $CONFIG_FILE $BACKUP_DIR/$ID/				
				read -p "Press ENTER to continue"
			;;
			[zZ]) read -p "** About to restore the example configuration stored in [ "$EXAMPLE_CONFIG" ] Press ENTER to proceed. "
				cp $EXAMPLE_CONFIG/$( basename $USERS_FILE ) $USERS_FILE
				cp $EXAMPLE_CONFIG/$( basename $USERS_GROUPS_FILE ) $USERS_GROUPS_FILE
				cp $EXAMPLE_CONFIG/$( basename $GROUPS_FILE ) $GROUPS_FILE				
				cp $EXAMPLE_CONFIG/$( basename $GROUPS_USERS_FILE )	$GROUPS_USERS_FILE 
				cp $EXAMPLE_CONFIG/$( basename $ACLS_FILE ) $ACLS_FILE 
				cp $EXAMPLE_CONFIG/$( basename $ACLS_PERMISSIONS_FILE ) $ACLS_PERMISSIONS_FILE 
				load_configuration
			;;					          			
			[xX]) echo -e "** ${BLUE}Goodbye.${NC}"
				exit 0
			;;
			*) echo -e "** ${RED}ERROR${NC}: Invalid input."
				read -p "Please choose a valid option"
			;;

		esac


done
echo "** Ready."
