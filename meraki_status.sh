#!/bin/bash
api_key=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx #Meraki Dashboard API Key
output_folder="/usr/lib/zabbix/externalscripts/" #Should be the externalscripts folder of your Zabbix installation, including trailing slash.
IFS=$'\n' orgs=(`cat meraki_networks.json | jq '.[] | .org_name' | sort | uniq | sed 's/\"//g'`) #List of Meraki orginizations to monitor seperated by new lines. 
#Increment through each org on the list
status(){
	i=$1	
	api_key=$2
	#Grabs the Org ID
	org_id=$(cat meraki_networks.json | jq --arg var1 "$i" '.[] |  select(.org_name == $var1 ).org_id' | sed 's/\"//g' | uniq)
	if [ ! -z "$org_id" ]; then
		#Grabs the Network name and ID
		IFS=$'\n' net_id=(`cat meraki_networks.json | jq --arg var1 "$org_id" '.[] | select(.org_id == $var1 ).id' | sed 's/\"//g'`)
		IFS=$'\n' net_name=(`cat meraki_networks.json | jq --arg var1 "$org_id" '.[] | select(.org_id == $var1 ).name' | sed 's/\"//g'`)
		#Retreive orginization device statuses
		devices_status=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/deviceStatuses --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
		devices=$(cat meraki_networks.json | jq --arg var1 "$org_id" '.[] | select(.org_id == $var1 )' | jq -s)
		uplinks=$(curl -L --request GET --url https://api.meraki.com/api/v1/organizations/$org_id/appliance/uplink/statuses --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key" | jq)
		#Places all of the values for a single netwok into a single string variable.
		devices="${devices} ${devices_status} ${uplinks}"
		#Merges the json objects together so that device details and statuses are within a single json object per device. 
		echo $devices | jq -s '[.[] | .[]] | group_by(.serial) | map(add)' >> devices.tmp
	else
		echo "Orginization $i was not found using your API key. Check to make sure the spelling is correct then try again"
	fi
}
export -f status
parallel -j 16 --link status ::: "${orgs[@]}" ::: $api_key
#Output finished json list
cat devices.tmp | jq -s > $output_folder"meraki.json"
rm devices.tmp
