# SAN/Storage CLI Toolbox
A collection of Simple SAN/Storage Command Line tools and utilities

* **fab_wwns.sh** - List all WWNS with additional info of a given Brocade fabric
* **hcs_hosts2ldevs.ps1** - PowerShell script (run it under Windows) to dump and correlate Hitachi Command Suite Hosts and LDEVs information. See the [blog](https://mezzantrop.wordpress.com/2016/11/30/fetching-data-from-hitachi-command-suite-with-hicommandcli-and-powershell/) for additional information.
* **zoneparse.sh** - Get and parse "zoneshow" from Brocade fabric switch
* **fashion** - A simple wrapper to run commands over SSH2
* **simmatch.sh** - Scan IBM SVC/Storwize system for "SCSI ID Mismatches". It shows the list of the same vdisks that are mapped with different SCSI IDs. Should be useful for clusters, especially VMware.
