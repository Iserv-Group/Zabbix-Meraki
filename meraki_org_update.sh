#!/bin/bash
api_key=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx #Meraki Dashboard API Key
#Grab basic Info for all Orginizations
org_info=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
#Creates full list of Org names
echo $org_info | jq '.[] | .name' | sed 's/\"//g' > list.tmp
#Filters out Orginizations that are purposfully ignored
IFS=$'\n' orgs=(`comm  -23 <(sort list.tmp ) <(sort org_ignore.txt)`)
rm list.tmp
#Increment through each org on the list
for i in "${orgs[@]}"; do
	#Pulls Org ID from list	
	org_id=$(echo $org_info | jq --arg var1 "$i" '.[] | select(.name == $var1 ).id' | sed 's/\"//g')
	if [ ! -z "$org_id" ]; then
		#Grabs the Network details via API calls
		networks=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/networks --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
		devices=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/devices --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
		#Detect and output any errors with the pull of network statistics
		echo $networks | jq '.errors | .[]' 2>/dev/null | sed 's/\"//g' | sed '/^[[:space:]]*$/d' > errors.tmp
		error_count=$(wc -l errors.tmp | awk '{print $1}')
		errors=$(cat errors.tmp)
		rm errors.tmp
		if [ $error_count -gt 0 ]; then
			#Create Json object with error, then skip processing for the org in question
			jo -p org_name="$i" error="$errors" >> json.tmp
			
		else
			#Creates a list variables with the network details
			IFS=$'\n' net_id=(`echo $networks | jq '.[] | .id' | sed 's/\"//g'`)
			IFS=$'\n' net_name=(`echo $networks | jq '.[] | .name' | sed 's/\"//g'`)
			c=0
			#Loops through each network and adds the Meraki network name, organization name and organization ID to all device json objects. 
			for a in "${net_id[@]}"; do
				dev+=$(echo $devices | jq --arg var "$a" --arg var2 "${net_name[$c]}" --arg var3 "$i" --arg var4 "$org_id" '[.[] | select(.networkId == $var )] | map(. + {network_name: $var2}) | map(. + {org_name: $var3}) | map(. + {org_id: $var4})')
				c=$c+1
			done
		fi
	else
		echo "Orginization $i was not found using your API key. Check to make sure the spelling is correct then try again"
	fi
done
#Create error JSON file to alert if there are any problems with data pulls
error_count=$(cat json.tmp | jq -s '.[] | .org_name' | wc -l)
array=$(cat json.tmp | jq -s)
rm json.tmp
jo -p errors_count=$error_count errors="$array" > /docker/zabbix/server/externalscripts/meraki_errors.json 
#Output finished json list
echo $dev | jq > "/home/iserv/scripts/meraki/meraki_networks.json"
