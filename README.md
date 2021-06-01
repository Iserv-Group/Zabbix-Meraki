# Overview
 The purpose of this script is to monitor the up status and other metrics of Meraki devices in Zabbix. This is accomplished by making API calls against the Meraki Dashboard using the external scripts function in Zabbix. Because this script uses external checks exclusively, everything is checked on the Zabbix server.
 To allow for separation of the Meraki API key from Zabbix, there are three scripts, the meraki_status_discovery.sh and meraki_status_quickpoll.sh scripts pull data from the APIs and outputs it to json files.  The meraki.sh script is used by Zabbix for discovery, status and other metrics purposes.
## Templated Zabbix items and triggers
 The Zabbix template is configured to create low priority alerts after a few minutes if a device or entire network becomes unreachable, then create increasingly higher priority alerts if the devices remain offline. The discovery process creates a single host within Zabbix for each Meraki network and adds it to a group based off its organization name in Meraki. 
 Alerts for discovered devices are dependent on an alert for the entire site. This is to reduce alerting to a single alarm if all the devices at a site go offline at the same time. 
# Installation
 1.	Start by downloading the repository and moving both scripts and the orgs.txt file to your Zabbix installation.
 2.	Place the meraki_status_discovery.sh and the meraki_quickpoll.sh scripts in a secure location on the Zabbix server and limit the read/write privileges on the script to super users to protect your API key. 
 3. Add a list of Meraki Organizations that you want to monitor to the orgs.txt file. 
	i.The organization names need to be exactly the same as they are found in Meraki
 4.	Modify the variables at the top of the meraki_status.sh script
	i. replace orgs.txt with the full path to the org.txt file
	ii.	Add your Meraki API key
	iii. Change the output folder to the location of the externalscripts folder of your Zabbix installation 
 5. Place the meraki.sh script in the externalscripts folder.
 6. Modify the folder variables at the top of the meraki_status.sh script to match your installation 
 7.	Run the meraki_status_quickpoll.sh script to see if a valid json file is created at externalscripts/meraki_quickpoll.json
 8.	Run the meraki_status_discovery.sh to see if a valid json file is created at externalscripts/meraki.json.json and meraki.networks.json
 9.	Assuming the test was successful, add the following two lines to a superuser crontab that has privileges to read/execute both scripts. Make sure to use the full path to both scripts, instead of the examples below. 

 ```
*/5 * * * * root /usr/share/zabbix/externalscripts/meraki_status_quickpoll.sh
2 */6 * * * root /usr/share/zabbix/externalscripts/meraki_status_discovery.sh
 ```

NOTE: These are the suggested cron scheduling entries for the proposed Zabbix Meraki scripts.  The meraki_status_quickpoll.sh entry is set to run every five minutes.
The meraki_status_discovery.sh entry is set to run every six hours (two minutes after the hour).  This will guarantee the Meraki template will have up to date data to perform the network discovery and host creation configured every 12 hours in the template.


 9. Import the templates into Zabbix
 10. Create a Host Group with the name of Meraki and give permissions to your users that include subgroups. 
 11. Apply the Meraki Network Discovery template to your Zabbix host, then run the discovery rule. 
