#!/bin/bash

#Location of the externalscripts folder
#If Zabbix is installed normally, both folder paths should be the same. If installed using docker, $docker_folder 
#should be the location as seen on the host, while output_folder should be the location as seen within the container.
docker_folder=$(echo "/usr/lib/zabbix/externalscripts/") 
output_folder=$(echo "/usr/lib/zabbix/externalscripts/")

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
#This section is setup as a cronjob because the script could take longer than the max 30 second Zabbix timeout on larger lists of organizations. 
if [ "$1" == "cron.network.discovery" ]; then
	IFS=$'\n' net_id=(`cat $docker_folder"meraki.json" | jq '.[] | select(.network_name | . == null or . == "" | not )' | jq '. | select(.network_name | test("(?i)ignore") | not ) | select(.network_name | test("(?i)pending") | not ).networkId' | sort | uniq | sed 's/\"//g'`)
	for i in "${net_id[@]}"; do
		org_name=$(cat $docker_folder"meraki.json" | jq --arg id "$i" '.[] | select(.networkId == $id ).org_name' | sort | uniq | sed 's/\"//g' | sed 's/\,//g' | sed 's/\.//g' | sed 's/\&/and/g' | tr -d '()' | tr -d \'\")
		network_name=$(cat $docker_folder"meraki.json" | jq --arg id "$i" '.[] | select(.networkId == $id ).network_name' | sort | uniq | sed 's/\"//g')
		notes=$(cat $docker_folder"meraki.json" | jq --arg id "$i" '.[] | select(.networkId == $id ) | select(.uplinks | length > 0).notes' | head -1 | sed 's/\"//g' | sed 's/\\r\\n/<br>/g' | sed 's/\\n/<br>/g' | sed 's/|/<br>/g')
		s1=$(echo '{#NETWORK_NAME}|{#ORG}|{#NETWORK_ID}|{#MX_NOTES}')
		s2=$(echo $network_name"|"$org_name"|"$i"|"$notes)
		s="${s1}"$'\n'"${s2}"
		#jq script that creates valid json output
		json_convert
	done
	json=$(echo ${json::-1})
	json+=$json_tail
	echo $json > $docker_folder"meraki.networks.json"
fi
#Discover Meraki Networks
if [ "$1" == "network.discovery" ]; then
	cat $output_folder"meraki.networks.json"
fi

#Discovers devices on a network. Takes Network ID as a variable
if [ "$1" == "device.discovery" ]; then
	IFS=$'\n' serial=(`cat $output_folder"meraki.json" | jq '(.[] | select(.name | . == null or . == "")).name |= "blank"' | jq --arg id "$2" '.[] | select(.networkId == $id) | select(.name | test("(?i)ignore") | not ) | select(.name | test("(?i)pending") | not ).serial' | sed 's/\"//g' 2>/dev/null`)
	for i in "${serial[@]}"; do
		name=$(cat $output_folder"meraki.json" | jq '(.[] | select(.name | . == null or . == "")).name |= "No device name in dashboard"' | jq --arg serial "$i" '.[] | select(.serial == $serial ).name' | sed 's/\"//g')
		notes=$(cat $output_folder"meraki.json" | jq --arg serial "$i" '.[] | select(.serial == $serial ).notes' | sed 's/\"//g' | sed 's/\\r\\n/<br>/g' | sed 's/\\n/<br>/g' | sed 's/|/<br>/g')
		s1=$(echo '{#NAME}|{#SERIAL}|{#NOTES}')
		s2=$(echo $name"|"$i"|"$notes)
		s="${s1}"$'\n'"${s2}"
		#jq script that creates valid json output
		json_convert
	done
	json=$(echo ${json::-1})
	json+=$json_tail
	echo $json
fi

#Discover any WAN uplinks on a network. Creates monitors for each uplink. It will discovery uplinks on secondary firewalls as well if they are present. Takes Network ID as a variable
if [ "$1" == "wan.discovery" ]; then
	#Create list of WAN Devices on a network
	IFS=$'\n' serial=(`cat $output_folder"meraki.json" | jq --arg id "$2" '.[] | select(.networkId == $id ) | select(.uplinks | length > 0) | select(.name | test("(?i)ignore") | not ) | select(.name | test("(?i)pending") | not ).serial' | sed 's/\"//g'`)
	IFS=$'\n' name=(`cat $output_folder"meraki.json" | jq --arg id "$2" '.[] | select(.networkId == $id ) | select(.uplinks | length > 0) | select(.name | test("(?i)ignore") | not ) | select(.name | test("(?i)pending") | not ).name' | sed 's/\"//g'`)
	IFS=$'\n' notes=(`cat $output_folder"meraki.json" | jq --arg id "$2" '.[] | select(.networkId == $id ) | select(.uplinks | length > 0) | select(.name | test("(?i)ignore") | not ) | select(.name | test("(?i)pending") | not ).notes' | sed 's/\"//g' | sed 's/\\r\\n/<br>/g' | sed 's/\\n/<br>/g'`)
	c1=0
	for i in "${serial[@]}"; do
		IFS=$'\n' int_name=(`cat $output_folder"meraki.json" | jq --arg serial "$i" '.[] | select(.serial == $serial) | .uplinks | .[] | select(.status != "not connected").interface' | sed 's/\"//g'`)
		IFS=$'\n' int_ip=(`cat $output_folder"meraki.json" | jq --arg serial "$i" '.[] | select(.serial == $serial) | .uplinks | .[] | select(.status != "not connected").publicIp' | sed 's/\"//g'`)
		c2=0
		for i in "${int_ip[@]}"; do
			s1=$(echo '{#NAME}|{#INT_IP}|{#INT_NAME}|{#NOTES}|{#NET_NAME}|{#SERIAL}')
			s2=$(echo ${name[$c1]}"|"$i"|""${int_name[$c2]}""|""${notes[$c1]}""|"$2"|""${serial[$c1]}")
			s="${s1}"$'\n'"${s2}"
			#jq script that creates valid json output
			json_convert
			c2=$c2+1
		done
		c1=$c1+1
	done
	json=$(echo ${json::-1})
	json+=$json_tail
	echo $json
fi

#Test's the status of a Meraki network as a whole. Takes Network ID as a variable
if [ "$1" == "network.status" ]; then
	cat $output_folder"meraki.json" | jq --arg id "$2" '.[] | select(.networkId == $id ).status' | sed 's/\"online\"/2/g' | sed 's/\"alerting\"/1/g' | sed 's/\"offline\"/0/g' | sort -r | head -1
fi
#Test device status. Takes serial number as argument
if [ "$1" == "device.status" ]; then
	cat $output_folder"meraki.json" | jq --arg id "$2" '.[] | select(.serial == $id ).status' | sed 's/\"online\"/2/g' | sed 's/\"alerting\"/1/g' | sed 's/\"offline\"/0/g' 
fi
#Test WAN status. Takes serial number as argument
if [ "$1" == "wan.status" ]; then
	cat $output_folder"meraki.json" | jq --arg serial "$2" --arg int_name "$3" '.[] | select(.serial == $serial ) | .uplinks | .[] | select(.interface == $int_name ).status' | sed 's/\"active\"/3/g' | sed 's/\"ready\"/2/g' | sed 's/\"failed\"/1/g' | sed 's/\"not connected\"/1/g'
fi
#Pulls full json list for every device on the network
if [ "$1" == "network.data" ]; then
	cat $output_folder"meraki.json" | jq --arg id "$2" '.[] | select(.networkId == $id )' | jq -s
fi
#Pulls list of errors from errors list
if [ "$1" == "errors.list" ]; then
	cat $output_folder"meraki_errors.json"
fi