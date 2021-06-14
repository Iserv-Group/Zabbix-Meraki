#!/bin/bash

#NOTES:
#This Meraki cloud API data pull script was created to generate an API aggregate data file that Zabbix can poll for network and device info periodically.  
#Files are created for every API call for easy reference and verification.  Comments have been added to make following the script progress easier.
#The data merge of all the API call data is done by merging the files themselves instead of variables in memory.  This should be easier on the server resources.
#Added ".uplinks." to the filenames to differenciate these as my additions from the original script on Github
#The complete script takes approximatetly two seconds to complete per device.  This is meant to be scheduled as a cron job at a regular long interval, such as a few times a day.
#Unlike the quickpoll script, this script is meant for Meraki network and device discovery, and to add info that does not change often, such as notes and address.


cd /usr/share/zabbix/externalscripts	#added this entry for cron job path.  Should be the same as the "output_folder" folder below.
IFS=$'\n' orgs=(`cat orgs.txt`) #List of Meraki organizations to monitor seperated by new lines.
api_key=************************** #Meraki Dashboard API Key
output_folder="/usr/share/zabbix/externalscripts/" #Should be the externalscripts folder of your Zabbix installation.

#Start of data collection for meraki.json file

#Increment through each org on the list
for org_txt in "${orgs[@]}"; do
        #Grabs the Org ID
        echo "---------- org_id API lookup"
        sleep 2
	org_id=$(curl -s -L --request GET --url https://api.meraki.com/api/v0/organizations --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key" | jq --arg var1 "$org_txt" '.[] | select(.name == $var1 ).id' | sed 's/\"//g')
        echo $org_id > $output_folder"meraki_status.devices.org_id.json"

        #Grabs the Network ID
        echo "---------- net_id API lookup"
        sleep 2
	IFS=$'\n' net_id=(`curl -s -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/networks --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key" | jq '.[] | .id' | sed 's/\"//g'`)
        echo ${net_id[*]} > $output_folder"meraki_status.devices.net_id.json"

	#Grabs the Network name
        echo "---------- net_name API lookup"
	sleep 2
        IFS=$'\n' net_name=(`curl -s -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/networks --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key" | jq '.[] | .name' | sed 's/\"//g'`)
        echo ${net_name[*]} > $output_folder"meraki_status.devices.net_name.json"

        #Retrieve organization device statuses
        echo "---------- device_status API lookup"
	sleep 2
        devices_status=$(curl -s -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/deviceStatuses --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
        echo ${devices_status[*]} > $output_folder"meraki_status.devices_status.json"


	#devices script for full number of host entries
        echo "---------- devices API lookup"
	cp /dev/null $output_folder"meraki_status.devices.json"
        HEADERS=$(mktemp)
	sleep 2
        LINK="https://api.meraki.com/api/v0/organizations/$org_id/devices?perPage=500"
        for (( i=1; i<=20; i++ )); do
                echo "-------------------- devices pass "$i
                QUERY=$(curl -D $HEADERS -s -L -H "X-Cisco-Meraki-API-Key: $api_key" -X GET -G -H 'Content-Type: application/json' "$LINK")
                sleep 2
                LINK=`cat $HEADERS | grep -i link |grep organizations| sed 's/.*<\(.*\)>; rel=next.*/\1/'`
                echo $QUERY >> $output_folder"meraki_status.devices.json"
                if [[ $LINK == *prev* ]]; then
                    rm -rf $HEADERS
                    break
                fi
                rm -rf $HEADERS
        done

        
        c=0
        #Places all of the values for a single network into a single string variable.
        echo "---------- appending devices API info payloads to file"
	cat $output_folder"meraki_status.devices.json" $output_folder"meraki_status.devices_status.json" | jq . > $output_folder"meraki_status.devicesapicombined.json"

        #Merges the json objects together so that device details and statuses are within a single json object per device.
        echo "---------- merging devices API info"
        cat $output_folder"meraki_status.devicesapicombined.json" | jq -s '[.[] | .[]] | group_by(.serial) | map(add)' > $output_folder"meraki_status.devicesapicombinedmerged.json"

        #Loops through each network and adds the Meraki network name, organization name and organization ID to all device json objects.
        echo "---------- adding org info to merged devices API info file in data loop"
        for a in "${net_id[@]}"; do
		#echo -ne "Processing Network ID: $a \r"
		dev+=$( jq --arg var "$a" --arg var2 "${net_name[$c]}" --arg var3 "$org_txt" --arg var4 "$org_id" '[.[] | select(.networkId == $var )] | map(. + {network_name: $var2}) | map(. + {org_name: $var3}) | map(. + {org_id: $var4})' $output_folder"meraki_status.devicesapicombinedmerged.json" )
		c=$((c+1))
        done
done
#Output finished json list
echo $dev | jq . > $output_folder"meraki.json"
echo "----- devices API info collection complete"

#End of data collection for meraki.json file



sleep 5



#Start of network discovery file generation section of the script

#Location of the externalscripts folder
#If Zabbix is installed normally, both folder paths should be the same. If installed using docker, $docker_folder
#should be the location as seen on the host, while output_folder2 should be the location as seen within the container.
docker_folder=$(echo "/usr/share/zabbix/externalscripts/")
output_folder2=$(echo "/usr/share/zabbix/externalscripts/")


#json variables for the json_convert function. Do not change.
json_head="{\"data\":["
json_tail="]}"
json=$json_head
#jq script function to convert variables to json output for Zabbix discovery
json_convert () {
        json+=$(jq -Rn '
        ( input  | split("|") ) as $keys |
        ( inputs | split("|") ) as $vals |
        [[$keys, $vals] | transpose[] | {key:.[0],value:.[1]}] | from_entries
        ' <<<"$s")
        json+=","
}

#Start of meraki.networks.json network discovery file generation
echo "---------- network discovery file generation"

        IFS=$'\n' net_id=(`cat $docker_folder"meraki.json" | jq '.[] | select(.network_name | test("(?i)ignore") | not ) | select(.network_name | test("(?i)pending") | not ).networkId' | sort | uniq | sed 's/\"//g'`)
        for q in "${net_id[@]}"; do
                org_name=$(cat $docker_folder"meraki.json" | jq --arg id "$q" '.[] | select(.networkId == $id ).org_name' | sort | uniq | sed 's/\"//g' | sed 's/\,//g' | sed 's/\.//g' | sed 's/\&/and/g' | tr -d '()' | tr -d \'\")
                network_name=$(cat $docker_folder"meraki.json" | jq --arg id "$q" '.[] | select(.networkId == $id ).network_name' | sort | uniq | sed 's/\"//g')
                s1=$(echo '{#NETWORK_NAME}|{#ORG}|{#NETWORK_ID}')
                s2=$(echo $network_name"|"$org_name"|"$q)
                s="${s1}"$'\n'"${s2}"
                #jq script that creates valid json output
                json_convert
        done
        json=$(echo ${json::-1})
        json+=$json_tail
        echo $json > $docker_folder"meraki.networks.json"

#End of meraki.networks.json network discovery file generation"
echo "----- meraki_status_discovery.sh script completed"





