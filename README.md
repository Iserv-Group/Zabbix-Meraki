# Overview
<<<<<<< Updated upstream
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
=======
 The purpose of this script is to monitor the status of Meraki devices in Zabbix. This is accomplished by making API calls against the Meraki Dashboard using the script function in Zabbix. Due to Meraki limiting the number of API queries that can be made from a single IP, some non-traditional template design choices were made to conform to Meraki’s preferred way of querying the API.
 This template is a modified version of the official Zabbix template for monitoring Meraki. Unlike previous versions of my own custom template for the same purpose, which used external checks relying on cron jobs on the host machine, it uses the new JavaScript based script item exclusively to gather data from Meraki. 
 The main upgrade over the official version is the ability to monitor a far larger number of devices before surpassing the Meraki API limit. This version accomplishes this by using Meraki’s preferred API call that gathers data for a whole organization, rather than a network or individual device like Zabbix’s official template. This data is then distributed to Zabbix Hosts that monitor whole networks by using Zabbix’s own API to retrieve data from the Organization level host. 
## Templated Zabbix items and triggers
 The Zabbix template is configured to create low priority alerts after a few minutes if a device or entire network becomes unreachable, then create increasingly higher priority alerts if the devices remain offline. The discovery process creates a single host within Zabbix for each Meraki network and adds it to a group based off its organization name in Meraki. 
 Alerts for discovered devices are dependent on an alert for the entire site. This is to reduce alerting to a single alarm if all the devices at a site go offline at the same time. 
 Lower level alerts from the official Zabbix template were kept including items for monitoring the configuration, license and checking for errors in the monitoring itself. 
# Setup
 Setup is much simpler in this version of the template, though there are still a few hoops to jump through
 1.	Start by downloading the repository and importing the Zabbix_templates file into your Zabbix instance. 
 2. If you don't have one already, create a API key for Zabbix. I would recommend creating a read only user, with permissions to the Meraki group, and create the API key under that account rather than one for an individual admin account. 
 3. If you don't have one already, create a API key for Meraki from their Dashboard.
 4. Next, create a host and apply the Meraki Dashboard by HTTP template to it. 
 5. Before saving the new host, switch to the Macros tab and enter all required Macros
    1. Both API keys are required. Make sure the value is saved as secret text.
	2. Entering the correct ZBX.URL is also required. The URL is the hostname/IP address of the web component of Zabbix as reachable by the Server component of Zabbix. The default value will work for most, but if you are using docker or a multi-server setup, you will need to set it to the hostname/IP for the web component.
	3. Enter regular expressions in the NAME.MATCHES and NAME.NOT_MATCHES values to explicitly include/exclude certain Organization and device names.
 6. After macros are set, save the host. 
 7. Once discovery is run, you should see several Zabbix hosts for your organizations created. Because Zabbix doesn't currently support [Nested LDD discovery](https://support.zabbix.com/browse/ZBXNEXT-1527 "Zabbix Feature Request") each organization level host will need to be full cloned before monitoring of the networks can begin. 
    1. To reduce the number of unneeded hosts, each Organization host should be cloned, deleted, then the cloned host's name should be changed to exactly what the discovered hosts name was. 
	2. Deleting the discovered host and changing the name of the cloned host to the what the discovered host was, will prevent the discovery process from creating a new host, which will reduce the number of requests to the Meraki API. 
 8. After completing this final step, monitoring should be setup 
# Known limitations
 Because the databases Zabbix uses have a character limit, there is a limit to how many devices can be in a single organization before problems start to arise. Due to how this version is written, and how much info the API dumps out, after more there are more than 90 devices in a single organization, discovery is likely to fail. I do have code written to reduce the information stored, per device, as well as break things out by network and item monitored, but I am not yet ready to port that code to this branch. 
 Because I don't have large enough networks or organizations that require paging through the API, I can't guarantee whether this template will work in those scenarios. Feel free to make a pull request if you do have either of these and can work out a solution. 
>>>>>>> Stashed changes


 9. Import the templates into Zabbix
 10. Create a Host Group with the name of Meraki and give permissions to your users that include subgroups. 
 11. Apply the Meraki Network Discovery template to your Zabbix host, then run the discovery rule. 
