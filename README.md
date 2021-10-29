# Overview
 The purpose of this script is to monitor the up status of Meraki devices in Zabbix. This is accomplished by making API calls against the Meraki Dashboard using the external scripts function in Zabbix. Because this script uses external checks exclusively, everything is checked on the Zabbix server.
 To allow for separation of the Meraki API key from Zabbix, there are two scripts, the meraki_status.sh script pulls data from the API and outputs it to a json file for the meraki.sh that is used by Zabbix for discovery and status purposes.
## Templated Zabbix items and triggers
 The Zabbix template is configured to create low priority alerts after a few minutes if a device or entire network becomes unreachable, then create increasingly higher priority alerts if the devices remain offline. The discovery process creates a single host within Zabbix for each Meraki network and adds it to a group based off its organization name in Meraki. 
 Alerts for discovered devices are dependent on an alert for the entire site. This is to reduce alerting to a single alarm if all the devices at a site go offline at the same time. 
# Installation
 1.	Start by downloading the repository and moving both scripts and the orgs.txt file to your Zabbix installation.
 2. Modify all three scripts so that they are executable.
 3. Install parallel using your distribution's package manager
 4.	Place the meraki_status.sh, meraki_org_update.sh and org_ignore.txt files in the same secure folder on the Zabbix server and limit the read/write privileges on the scripts to super users to protect your API key.
 5. Add a list of any Meraki Organizations that your API key has access to but you would like to exclude from monitoring to the org_ignore.txt file. 
	1.The organization names need to be exactly the same as they are found in Meraki
 6.	Modify the variables at the top of the meraki_status.sh and meraki_org_update.sh scripts
	1. Add your Meraki API key.
	2. Change the input folder to the location where you have the script stored.
	3. Change the output folder to the location of the externalscripts folder of your Zabbix installation.
 7. Place the meraki.sh script in the externalscripts folder.
 8. Modify the folder variables at the top of the meraki_status.sh script to match your installation
 9. Run the meraki_org_update.sh and make sure that the meraki_networks.json and externalscripts/meraki_errors.json files are created and that they have valid json
 10.	Run the meraki_status.sh script and make sure that the externalscripts/meraki.json file is created and that it has valid json
 11.	Assuming the test was successful, add the following lines to a superuser crontab that has privileges to read/execute all three scripts. Make sure to use the full path to all three scripts on your installation, instead of the examples below. 

 ```
 #Updates list of Meraki orginizations and devices
 0 * * * * /home/user/scripts/meraki_org_update.sh
 #Updates status of Meraki devices
 * * * * * /home/user/scripts/meraki_status.sh
 #Updates list of discovered networks. Used for the Zabbix discovery process
 */10 * * * * /usr/lib/zabbix/externalscripts/meraki.sh cron.network.discovery
 ```

 12. Import the template into Zabbix
 13. Create a Host Group with the name of Meraki and give permissions to your users that include subgroups. 
 14. Apply the Meraki Network Discovery template to your Zabbix Server host, then run the discovery rule. 

