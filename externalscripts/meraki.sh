#!/bin/bash
#set -x
json_head="{\"data\":["
json_tail="]}"
json=$json_head

json_convert () {
	json+=$(jq -Rn '
	( input  | split("|") ) as $keys |
	( inputs | split("|") ) as $vals |
	[[$keys, $vals] | transpose[] | {key:.[0],value:.[1]}] | from_entries
	' <<<"$s")
	json+=","
}

if [ "$1" == "cron.network.discovery" ]; then
	IFS=$'\n' net_id=(`cat /docker/zabbix/server/externalscripts/meraki.json | jq '.[] | .networkId' | sort | uniq | sed 's/\"//g'`)
	for i in "${net_id[@]}"; do
		org_name=$(cat /docker/zabbix/server/externalscripts/meraki.json | jq --arg id "$i" '.[] | select(.networkId == $id ).org_name' | sort | uniq | sed 's/\"//g' | sed 's/\,//g' | sed 's/\.//g' | sed 's/\&/and/g' | tr -d '()' | tr -d \'\")
		network_name=$(cat /docker/zabbix/server/externalscripts/meraki.json | jq --arg id "$i" '.[] | select(.networkId == $id ).network_name' | sort | uniq | sed 's/\"//g')
		notes=$(cat /docker/zabbix/server/externalscripts/meraki.json | jq --arg id "$i" '.[] | select(.networkId == $id ) | select(.uplinks | length > 0).notes' | head -1 | sed 's/\"//g' | sed 's/\\r\\n/<br>/g' | sed 's/\\n/<br>/g')
		s1=$(echo '{#NETWORK_NAME}|{#ORG}|{#NETWORK_ID}|{#MX_NOTES}')
		s2=$(echo $network_name"|"$org_name"|"$i"|"$notes)
		s="${s1}"$'\n'"${s2}"
		#jq script that creates valid json output
		json_convert
	done
	json=$(echo ${json::-1})
	json+=$json_tail
	echo $json > /docker/zabbix/server/externalscripts/meraki.networks.json
fi
#Discover Meraki Networks
if [ "$1" == "network.discovery" ]; then
	cat /usr/lib/zabbix/externalscripts/meraki.networks.json
fi

#Discovers devices on a network. Takes Network ID as a variable
if [ "$1" == "device.discovery" ]; then
	IFS=$'\n' serial=(`cat /usr/lib/zabbix/externalscripts/meraki.json | jq --arg id "$2" '.[] | select(.networkId == $id) | select(.network_name | index("pending") | not ) | select(.network_name | index("PENDING") | not) | select(.network_name | index("pending") | not )' | sed 's/\"//g'`)
	for i in "${serial[@]}"; do
		name=$(cat /usr/lib/zabbix/externalscripts/meraki.json | jq --arg serial "$i" '.[] | select(.serial == $serial ).name' | sed 's/\"//g')
		notes=$(cat /usr/lib/zabbix/externalscripts/meraki.json | jq --arg serial "$i" '.[] | select(.serial == $serial ).notes' | sed 's/\"//g' | sed 's/\\r\\n/<br>/g' | sed 's/\\n/<br>/g')
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

#Discover any WAN uplinks on a network. Creates monitors for each uplink. Takes Network ID as a variable
if [ "$1" == "wan.discovery" ]; then
	#Create list of WAN Devices on a network
	IFS=$'\n' serial=(`cat /usr/lib/zabbix/externalscripts/meraki.json | jq --arg id "$2" '.[] | select(.networkId == $id ) | select(.uplinks | length > 0).serial' | sed 's/\"//g'`)
	IFS=$'\n' name=(`cat /usr/lib/zabbix/externalscripts/meraki.json | jq --arg id "$2" '.[] | select(.networkId == $id ) | select(.uplinks | length > 0).name' | sed 's/\"//g'`)
	IFS=$'\n' notes=(`cat /usr/lib/zabbix/externalscripts/meraki.json | jq --arg id "$2" '.[] | select(.networkId == $id ) | select(.uplinks | length > 0).notes' | sed 's/\"//g' | sed 's/\\r\\n/<br>/g' | sed 's/\\n/<br>/g'`)
	c1=0
	for i in "${serial[@]}"; do
		IFS=$'\n' int_name=(`cat /usr/lib/zabbix/externalscripts/meraki.json | jq --arg serial "$i" '.[] | select(.serial == $serial) | .uplinks | .[] | select(.status != "not connected").interface' | sed 's/\"//g'`)
		IFS=$'\n' int_ip=(`cat /usr/lib/zabbix/externalscripts/meraki.json | jq --arg serial "$i" '.[] | select(.serial == $serial) | .uplinks | .[] | select(.status != "not connected").publicIp' | sed 's/\"//g'`)
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
	cat /usr/lib/zabbix/externalscripts/meraki.json | jq --arg id "$2" '.[] | select(.networkId == $id ).status' | sed 's/\"online\"/2/g' | sed 's/\"alerting\"/1/g' | sed 's/\"offline\"/0/g' | sort -r | head -1
fi
#Test device status. Takes serial number as argument
if [ "$1" == "device.status" ]; then
	cat /usr/lib/zabbix/externalscripts/meraki.json | jq --arg id "$2" '.[] | select(.serial == $id ).status' | sed 's/\"online\"/2/g' | sed 's/\"alerting\"/1/g' | sed 's/\"offline\"/0/g' 
fi
if [ "$1" == "wan.status" ]; then
	cat /usr/lib/zabbix/externalscripts/meraki.json | jq --arg serial "$2" --arg int_name "$3" '.[] | select(.serial == $serial ) | .uplinks | .[] | select(.interface == $int_name ).status' | sed 's/\"active\"/3/g' | sed 's/\"ready\"/2/g' | sed 's/\"failed\"/1/g' | sed 's/\"not connected\"/1/g'
fi

