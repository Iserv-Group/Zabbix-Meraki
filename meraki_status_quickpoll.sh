#!/bin/bash

#NOTES:
#This Meraki cloud API data pull script was created to generate an API aggregate data file that Zabbix can poll periodically.  
#Files are created for every API call for easy reference and verification.  Comments have been added to make following the script progress easier.
#The data merge of all the API call data is done by merging the files themselves instead of variables in memory.  This should be easier on the server resources.
#Added ".uplinks." to the filenames to differenciate these as my additions from the original script on Github
#The complete script takes approximatetly one second to complete per 75 devices.  This is meant to be scheduled as a cron job at a regular short interval, such as every five minutes, to provide the best picture of the Meraki network environment.



cd /usr/share/zabbix/externalscripts
IFS=$'\n' orgs=(`cat orgs.txt`) #List of Meraki organizations to monitor seperated by new lines. 
api_key=****************************** #Meraki Dashboard API Key
output_folder="/usr/share/zabbix/externalscripts/" #Should be the externalscripts folder of your Zabbix installation.

#Start of data collection for meraki_quickpoll.json file

#Increment through each org on the list
for org_txt in "${orgs[@]}"; do
	#Grabs the Org ID
	echo "---------- org_id quickpoll API lookup"
	org_id=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key" | jq --arg var1 "$org_txt" '.[] | select(.name == $var1 ).id' | sed 's/\"//g')
	echo $org_id > $output_folder"meraki_status.quickpoll.org_id.json"
	
	#Retrieve organization device statuses 
	echo "---------- device_status quickpoll API lookup"
	devices_status=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/deviceStatuses --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
	echo ${devices_status[*]} > $output_folder"meraki_status.quickpoll.devices_status.json"

	#Retrieve uplinks script for full number of host entries
	echo "---------- uplinks quickpoll API lookup"
	cp /dev/null $output_folder"meraki_status.quickpoll.uplink.status.json"
	HEADERS=$(mktemp)
        LINK="https://api.meraki.com/api/v1/organizations/$org_id/appliance/uplink/statuses?perPage=800"
        for (( i=1; i<=20; i++ )); do
		echo "-------------------- uplinks pass" $i
                QUERY=$(curl -D $HEADERS -L -H "X-Cisco-Meraki-API-Key: $api_key" -X GET -G -H 'Content-Type: application/json' "$LINK")
                LINK=`cat $HEADERS | grep -i link |grep organizations| sed 's/.*<\(.*\)>; rel=next.*/\1/'`
                echo $QUERY >> $output_folder"meraki_status.quickpoll.uplink.status.json"
                if [[ $LINK == *prev* ]]; then
                    rm -rf $HEADERS
                    break
                fi
                rm -rf $HEADERS
        done
	
	#Retrieve organization device loss and latency 
	echo "---------- losslatency quickpoll API lookup"
	loss_latency=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/uplinksLossAndLatency?timespan=60 --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
	echo ${loss_latency[*]} > $output_folder"meraki_status.quickpoll.loss_latency.json"

	#Places all of the values for a single network into a single string variable.
	echo "---------- appending quickpoll API payloads to file"
	cat $output_folder"meraki_status.quickpoll.devices_status.json" $output_folder"meraki_status.quickpoll.uplink.status.json" $output_folder"meraki_status.quickpoll.loss_latency.json" | jq . > $output_folder"meraki_status.quickpoll.loss_apicombined.json"
	
	#Merges the json objects together so that device details and statuses are within a single json object per device. 
	echo "---------- merging quickpoll API data"
	cat $output_folder"meraki_status.quickpoll.loss_apicombined.json" | jq -s '[.[] | .[]] | group_by(.serial) | map(add)' > $output_folder"meraki_quickpoll.json"
done
#End of data collection for meraki_quickpoll.json file
echo "----- meraki_status_quickpoll.sh script completed"
