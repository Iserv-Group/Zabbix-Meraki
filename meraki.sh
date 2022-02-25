#!/bin/bash
cd /usr/share/zabbix/externalscripts

#Location of the externalscripts folder
#If Zabbix is installed normally, both folder paths should be the same. If installed using docker, $docker_folder 
#should be the location as seen on the host, while output_folder should be the location as seen within the container.
docker_folder=$(echo "/usr/share/zabbix/externalscripts/") 
output_folder=$(echo "/usr/share/zabbix/externalscripts/")

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


#Discover Meraki Networks
if [ "$1" == "network.discovery" ]; then
	cat $output_folder"meraki.networks.json"
fi


#Discovers devices on a network. Takes Network ID as a variable
if [ "$1" == "device.discovery" ]; then
	IFS=$'\n' serial=(`cat $output_folder"meraki.json" | jq --arg id "$2" '.[] | select(.networkId == $id) | select(.name | test("(?i)ignore") | not ) | select(.name | test("(?i)pending") | not ).serial' | sed 's/\"//g'`)
	for i in "${serial[@]}"; do
		name=$(cat $output_folder"meraki.json" | jq --arg serial "$i" '.[] | select(.serial == $serial ).name' | sed 's/\"//g')
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
        IFS=$'\n' serial=(`cat $output_folder"meraki_quickpoll.json" | jq --arg id "$2" '.[] | select(.networkId == $id ) | select(.uplinks | length > 0) | select(.name | test("(?i)ignore") | not ) | select(.name | test("(?i)pending") | not ).serial' | sed 's/\"//g'`)
        IFS=$'\n' name=(`cat $output_folder"meraki_quickpoll.json" | jq --arg id "$2" '.[] | select(.networkId == $id ) | select(.uplinks | length > 0) | select(.name | test("(?i)ignore") | not ) | select(.name | test("(?i)pending") | not ).name' | sed 's/\"//g'`)
        IFS=$'\n' notes=(`cat $output_folder"meraki_quickpoll.json" | jq --arg id "$2" '.[] | select(.networkId == $id ) | select(.uplinks | length > 0) | select(.name | test("(?i)ignore") | not ) | select(.name | test("(?i)pending") | not ).notes' | sed 's/\"//g' | sed 's/\\r\\n/<br>/g' | sed 's/\\n/<br>/g'`)
        c1=0
        for i in "${serial[@]}"; do
                IFS=$'\n' int_name=(`cat $output_folder"meraki_quickpoll.json" | jq --arg serial "$i" '.[] | select(.serial == $serial) | .uplinks | .[] | select(.status != "not connected").interface' | sed 's/\"//g'`)
                IFS=$'\n' int_ip=(`cat $output_folder"meraki_quickpoll.json" | jq --arg serial "$i" '.[] | select(.serial == $serial) | .uplinks | .[] | select(.status != "not connected").publicIp' | sed 's/\"//g'`)
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


#DEVICE CHECK - Pulls full json info list for every device on the network
if [ "$1" == "network.data" ]; then
	cat $output_folder"meraki.json" | jq --arg id "$2" '.[] | select(.networkId == $id )' | jq -s .
fi


#UPLINK CHECK - Pulls full json info list for every device uplink on the network
if [ "$1" == "network.uplink.data" ]; then
        cat $output_folder"meraki_quickpoll.json" | jq --arg id "$2" '.[] | select(.networkId == $id )' | jq -s .
fi
<<<<<<< Updated upstream

=======
#Pulls list of errors from errors list
if [ "$1" == "errors.list" ]; then
	cat $output_folder"meraki_errors.json"
fi
#Pulls size of json file for monitoring of potential issues
if [ "$1" == "size.data" ]; then
	wc -c $output_folder"meraki.json" | awk -F ' ' '{print $1}'
fi
>>>>>>> Stashed changes
