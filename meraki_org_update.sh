#!/bin/bash
api_key=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx #Meraki Dashboard API Key
output_folder="/usr/lib/zabbix/externalscripts/" #Should be the externalscripts folder of your Zabbix installation.
input_folder="/home/user/scripts/" #should be the folder the script is located in
#Grab basic Info for all Orginizations
org_info=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
#Creates full list of Org names
echo $org_info | jq '.[] | .name' | sed 's/\"//g' > list.tmp
#Filters out Orginizations that are purposfully ignored
IFS=$'\n' orgs=(`comm  -23 <(sort list.tmp ) <(sort $input_folder"org_ignore.txt")`)
rm list.tmp
#Increment through each org on the list
for i in "${orgs[@]}"; do
	#Pulls Org ID from list	
	org_id=$(echo $org_info | jq --arg var1 "$i" '.[] | select(.name == $var1 ).id' | sed 's/\"//g')
	if [ ! -z "$org_id" ]; then
		#Grabs the Network details via API calls
		networks=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/networks --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key")
		curl -L --request GET --url https://api.meraki.com/api/v0/organizations/$org_id/devices --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key" > devcies.tmp
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
			#Declare merge function for use in parallel command 
			merge(){
			devices=$(cat devcies.tmp)
			echo $devices | jq --arg var "$1" --arg var2 "$2" --arg var3 "$3" --arg var4 "$4" '[.[] | select(.networkId == $var )] | map(. + {network_name: $var2}) | map(. + {org_name: $var3}) | map(. + {org_id: $var4})' >> orgs.tmp
			}
			export -f merge
			parallel -j 4 --link merge ::: "${net_id[@]}" ::: "${net_name[@]}" ::: $i ::: $org_id
		fi
	else
		echo "Orginization $i was not found using your API key. Check to make sure the spelling is correct then try again"
	fi
done
#Create error JSON file to alert if there are any problems with data pulls
error_count=$(cat json.tmp | jq -s '.[] | .org_name' | wc -l)
array=$(cat json.tmp | jq -s)
rm json.tmp
jo -p errors_count=$error_count errors="$array" > $output_folder"meraki_errors.json" 
#Output finished json list
cat orgs.tmp | jq > $input_folder"meraki_networks.json"
rm orgs.tmp
rm devcies.tmp