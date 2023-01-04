This is a fork of MrCirca's [repository](https://github.com/MrCirca/zabbix-routeros-bgp), updated to be compatible with RouterOS 7. Originally created by @buduboti and updated by @rbaldasso with graphs for uptime, support for custom SSH ports, fixes to the peer state being incorrectly retrieved, fixes for the uptime calculation and more.

### Installation

Import the template, set the macros (user credentials and SSH portfor zabbix) and copy the [bgp_peer.sh](/bgp_peer.sh) script to the externalscripts directory ([link](https://www.zabbix.com/documentation/current/en/manual/config/items/itemtypes/external#external-check-result)).

Create the files below and make sure that they are owned by the Zabbix user:

 * /usr/share/zabbix/bgp-peer-all-status
 * /usr/share/zabbix/bgp-peer-statuses
 * Make sure that the Zabbix folder is owned by the Zabbix user for the SSH to work properly
 * Install sshpass (apt install sshpass or yum install sshpass)
 
### Requirements

 * sshpass
 * RouterOS >=7.6
 * Zabbix >=6
