#!/bin/bash

#NOTES:
#This Meraki API data pull script was created specifically to generate a data file containing device VPN tunnel statistics that Zabbix can poll periodically.  
#The complete script takes roughly 48 seconds to complete for me per 1000 devices.
#Comments have been added to follow the script progress easier.
#Added ".uplinks." to the filenames to differenciate these as my additions from the original script on Github

IFS=$'\n' orgs=(`cat orgs.txt`) #List of Meraki organizations to monitor separated by new lines.  This is the list of actual org names, not org numbers.
api_key=*************API KEY********* #Meraki Dashboard API Key
output_folder="/usr/share/zabbix/externalscripts/" #Should be the externalscripts folder of your Zabbix installation.
#Increment through each org on the list
for i in "${orgs[@]}"; do
        #Grabs the Org ID
        echo "---------- org_id API lookup"
        org_id=$(curl -L --request GET --url https://api.meraki.com/api/v0/organizations --header 'Content-Type: application/json' --header 'Accept: application/json' --header "X-Cisco-Meraki-API-Key: $api_key" | jq --arg var1 "$i" '.[] | select(.name == $var1 ).id' | sed 's/\"//g')
        echo $org_id > $output_folder"meraki_status.org_id.json"

        #Retrieve vpn stats for full number of host entries
        #Running a straight "curl get" command gives me 300 entries.  By capturing the page headers and looping the process to "turn the page" to the next 300 and so on I am able to obtain all of the records in the organization.
        echo "---------- vpn stats API lookup"
        cat $output_folder"empty.txt" > $output_folder"meraki_status.uplink.vpn_stats_unfiltered.json"
        HEADERS=$(mktemp)
        LINK="https://api.meraki.com/api/v1/organizations/$org_id/appliance/vpn/stats?perPage=300"
        for (( i=1; i<=20; i++ )); do
                echo "-------------------- vpn stats pass" $i
                QUERY2=$(curl -D $HEADERS -L -H "X-Cisco-Meraki-API-Key: $api_key" -X GET -G -H 'Content-Type: application/json' "$LINK")
                sleep 1
                LINK=`cat $HEADERS | grep -i link |grep organizations| sed 's/.*<\(.*\)>; rel=next.*/\1/'`
                echo $QUERY2 >> $output_folder"meraki_status.uplink.vpn_stats_unfiltered.json"
                uplinks+=$QUERY2
                if [[ $LINK == *prev* ]]; then
                    rm -rf $HEADERS
                    break
                fi
                rm -rf $HEADERS
        done
        #Apply jq filters to the data file to prune out all head end Meraki hub VPN tunnels (this example hub names start with CENTRAL-HUB or BACKUP-HUB).  I just wanted the VPN tunnel statistics for the spoke Meraki devices.
	cat $output_folder"meraki_status.uplink.vpn_stats_unfiltered.json" | jq '.[] | select(.networkName | startswith("CENTRAL-HUB") or startswith("BACKUP-HUB")| not)' | jq [.] > $output_folder"meraki_status.uplink.vpn_stats.json"

	#If you wish to combine this script with the meraki_quickpoll.sh script, then uncomment the echo and cat lines below.
	#Places all of the apicombined and VPN statistics json files data for a single organization into a single file (ie: file1+file2=file4).
        #echo "---------- appending API combined file and vpn stats file"
        #cat $output_folder"meraki_quickpoll.json" $output_folder"meraki_status.uplink.vpn_stats.json" | jq . > $output_folder"meraki_status.uplink.loss_apicombined_vpn.json"

        #Merges the json objects together so that device details and statuses are within a single json object per device.
        #echo "---------- merging API combined and vpn stats data"
        #cat $output_folder"meraki_status.uplink.loss_apicombined_vpn.json" | jq -s '[.[] | .[]] | group_by(.networkId) | map(add)' > $output_folder"meraki_quickpoll2.json"
	
	#If this last section is used, the final merged output "meraki_quickpoll2.json" file is to be polled periodically by Zabbix to populate the host item data.
done

#If the last commented section is not used, the final output "meraki_status.uplink.vpn_stats.json" file is to be polled periodically by Zabbix to populate the host item data.
