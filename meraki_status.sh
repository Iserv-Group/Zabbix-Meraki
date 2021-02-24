#!/bin/bash
IFS=$'\n' orgs=(`cat orgs.txt`) #List of Meraki orginizations to monitor seperated by new lines. 
api_key=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx #Meraki Dashboard API Key
output_folder="/usr/lib/zabbix/externalscripts/" #Should be the externalscripts folder of your Zabbix installation.
#Increment through each org on the list
for i in "${orgs[@]}"; do
	#Grabs the Org ID
	org_id=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key" | jq --arg var1 "$i" '.[] | select(.name == $var1 ).id' | sed 's/\"//g')
	#Grabs the Network name and ID
	IFS=$'\n' net_id=(`curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/networks --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key" | jq '.[] | .id' | sed 's/\"//g'`)
	IFS=$'\n' net_name=(`curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/networks --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key" | jq '.[] | .name' | sed 's/\"//g'`)
	#Retreive orginization device statuses
	devices_status=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/deviceStatuses --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
	devices=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/devices --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
	uplinks=$(curl -L --request GET --url https://api.meraki.com/api/v1/organizations/$org_id/appliance/uplink/statuses --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
	c=0
	devices="${devices} ${devices_status} ${uplinks}"
	devices=$(echo $devices | jq -s '[.[] | .[]] | group_by(.serial) | map(add)')
	for a in "${net_id[@]}"; do
		dev+=$(echo $devices | jq --arg var "$a" --arg var2 "${net_name[$c]}" --arg var3 "$i" --arg var4 "$org_id" '[.[] | select(.networkId == $var )] | map(. + {network_name: $var2}) | map(. + {org_name: $var3}) | map(. + {org_id: $var4})')
		c=$c+1
	done
done
echo $dev | jq > $output_folder"meraki.json"
