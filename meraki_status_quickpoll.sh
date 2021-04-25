#!/bin/bash

#NOTES:
#This Meraki cloud API data pull script was created to generate an API aggregate data file that Zabbix can poll periodically.  
#The complete script takes approximately 75 seconds to complete for me.
#Files are created for every API call for easy reference and verification.  Comments have been added to make following the script progress easier.
#The data merge of all the API call data is done by merging the files themselves instead of variables in memory.  This should be easier on the server resources.
#Added ".uplinks." to the filenames to differenciate these as my additions from the original script on Github

IFS=$'\n' orgs=(`cat orgs.txt`) #List of Meraki organizations to monitor separated by new lines.  This is the list of actual org names, not org numbers.
api_key=*************API KEY********* #Meraki Dashboard API Key
output_folder="/usr/share/zabbix/externalscripts/" #Should be the externalscripts folder of your Zabbix installation.
#Increment through each org on the list above
for i in "${orgs[@]}"; do
        #Grabs the Org ID
        echo "---------- org_id API lookup"
        org_id=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key" | jq --arg var1 "$i" '.[] | select(.name == $var1 ).id' | sed 's/\"//g')
        echo $org_id > $output_folder"meraki_status.uplink.org_id.json"

        #Retrieve organization device statuses
        echo "---------- device_status API lookup"
        devices_status=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/deviceStatuses --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
        echo ${devices_status[*]} > $output_folder"meraki_status.uplink.devices_status.json"

        #Retrieve device uplinks for full number of host entries
        #Running a straight "curl get" command gives me exactly 1000 entries.  By capturing the page headers and looping the process to "turn the page" to the next 1000 and so on I am able to obtain all of the records in the organization.
        echo "---------- device uplinks API lookup"
        cat $output_folder"empty.txt" > $output_folder"meraki_status.uplink.status.json"
        HEADERS=$(mktemp)
        LINK="https://api.meraki.com/api/v1/organizations/$org_id/appliance/uplink/statuses?perPage=1000"
        for (( i=1; i<=20; i++ )); do
                echo "-------------------- uplinks pass" $i
                QUERY=$(curl -D $HEADERS -L -H "X-Cisco-Meraki-API-Key: $api_key" -X GET -G -H 'Content-Type: application/json' "$LINK")
                sleep 1
                LINK=`cat $HEADERS | grep -i link |grep organizations| sed 's/.*<\(.*\)>; rel=next.*/\1/'`
                echo $QUERY >> $output_folder"meraki_status.uplink.status.json"
                uplinks+=$QUERY
                if [[ $LINK == *prev* ]]; then
                    rm -rf $HEADERS
                    break
                fi
                rm -rf $HEADERS
        done

        #Retrieve organization device loss and latency for only one entry (60 seconds) instead of five entries (1 min x5).
        echo "---------- losslatency API lookup"
        loss_latency=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/uplinksLossAndLatency?timespan=60 --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
        echo ${loss_latency[*]} > $output_folder"meraki_status.uplink.loss_latency.json"


        #Places all of the json files data for a single organization into a single file (ie: file1+file2+file3=file4).
        echo "---------- appending API payloads to single file"
        cat $output_folder"meraki_status.uplink.devices_status.json" $output_folder"meraki_status.uplink.status.json" $output_folder"meraki_status.uplink.loss_latency.json" | jq . > $output_folder"meraki_status.uplink.loss_apicombined.json"

        #Merges the json objects together so that device details and statuses are within a single json object per device.
        echo "---------- merging API data"
        cat $output_folder"meraki_status.uplink.loss_apicombined.json" | jq -s '[.[] | .[]] | group_by(.serial) | map(add)' > $output_folder"meraki_quickpoll.json"
done

#The final merged output "meraki_quickpoll.json" file is to be polled periodically by Zabbix to populate the host item data.
