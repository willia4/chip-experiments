# SNMP Bandwidth

## Some Assembly Required

Install the [net-snmp](http://www.net-snmp.org/) tools on some computer (it doesn't necessarily have to be CHIP). 

Use the snmpbulkwalk command to see what your router can tell you -- and how it identifies that. 

    snmpbulkwalk -c <COMMUNITY> <ROUTER_HOSTNAME> IFTable

will find out everything your router can tell you about the network interface table. This will return a lot of data. 

First, I looked for the `ifName` entry for `eth0` since I know that my router uses `eth0` as the WAN interface. 

I found `IF-MIB::ifName.2 = STRING: eth0` which tells me that my router reports `eth0` as network interface **2**. 

I then found `IF-MIB::ifInOctets.2` which is a counter that tells me how many bytes have come in on that interface since the router started counting. 

So `IF-MIB::ifInOctets.2` will be the numeric counter for reporting my bandwidth. I'll use this to configure the script.

# Gems

    gem install snmp
