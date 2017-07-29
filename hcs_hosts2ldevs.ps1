# -----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# zmey20000@yahoo.com wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return Mikhail Zakharov
# -----------------------------------------------------------------------------
 
#
# Dump and correlate Hitachi Command Suite Hosts and LDEVs information
#
 
#
# v1.0  2016.11.30  Initial release
# v1.1  2016.12.16  Storage serial and model/type added
 
# Usage:
# hcs_hosts2ldevs -hcs_host hcs8.server.name -hcs_user user -hcs_pass password -hcs_cli X:\HCS\CLI\HiCommandCLI.bat -out_csv X:\path\to\your.csv
 
 
# Defaul values ---------------------------------------------------------------
param (
    [string]$hcs_host = "hcs8.server.name",
    [string]$hcs_user = "system",
    [string]$hcs_pass = "manager",
    [string]$hcs_cli = "C:\HCS_CLI\HiCommandCLI.bat",
    [string]$out_csv = "HCS-Hosts2LDEVs.csv"
)
 
# -----------------------------------------------------------------------------
$hcs_url="http://" + $hcs_host + ":2001/service"
 
Write-Host "Querying HCS data. You have time for a cup of coffee"
 
$flist = & $hcs_cli $hcs_url GetHost "subtarget=LogicalUnit" -u $hcs_user -p $hcs_pass |
    where {$_ -cmatch "name=|capacityInKB=|osType=|instance|WWN=|displayName=|emulation=|consumedCapacityInKB|commandDevice|arrayGroupName|raidType|externalVolume|dpType|dpPoolID|objectID"}
 
Write-Host "Processing HCS data. Keep calm and enjoy your drink"
$i = 0
Add-Content $out_csv "Hostname,Host capacity (MB),OS,WWN,LDEV,LDEV capacity (MB),Storage System SN,Storage System Type,LDEV Used (MB),Emulation,Array Group,RAID level,Command Device,External,DP Type,DP Pool ID"
foreach ($ln in $flist) {
 
    # Show some progress indication
    $i += 1
    if ($i % 10000 -eq 0) {
        Write-Host Row $i : $flist.Length processed
    }      
   
    # Split every line to fetch 'variable' and 'value' parts
    $hash=$ln.Trim().Split('=')
 
    # Fetch Host/WWN/LDEV data and combine everything together to prepare normal table format
    switch ($hash[0]) {
        "An instance of Host" {
            if ($LUN -ne "") {
                $LUNs += $LUN + $SS + $ST + $LUsed + $Emul + $RG + $RGLvl + $CMDDev + $Ext + $DPType + $DPPool
            }
           
            foreach ($wc in $WWNs) {
                foreach ($lc in $LUNs) {
                    if ("$Hst$OS$wc$lc" -ne "") {
                        Add-Content $out_csv $Hst$OS$wc$lc
                    }
                }
            }
 
            # Clean variables for the next host
            $Hst = ""
            $LUN = ""
            $OS = ","
            $Emul = ",";
           
            $WWNs = @()
            $LUNs = @()
           
            # We are at Host Level: 0
            $l = 0
            break
        }
       
        "name" {
            $Hst += $hash[1]
            break
        }
 
        "capacityInKB" {
            # Capacity can be found on Level 0 and Level 2
            switch ($l) {
                0 {$Hst += "," + $hash[1].Replace(".", "")/1024; break}
                2 {$LUN += "," + $hash[1].Replace(".", "")/1024; break}
            }              
        }
 
        "osType" {
            $OS = "," + $hash[1]
            break
        }
       
        "An instance of WWN" {
            # Go down to WWN Level: 1
            $l = 1
            break
        }
 
        "WWN" {
            $WWNs += "," + $hash[1].Replace(".", ":").ToLower()
            break
        }
       
        "An instance of LogicalUnit" {
            if ($LUN -ne "") {
                $LUNs += $LUN + $SS + $ST + $LUsed + $Emul + $RG + $RGLvl + $CMDDev + $Ext + $DPType + $DPPool
                $LUN = ""; $SS = ""; $ST = ""; $Emul = ","; $LUsed = ","; $CMDDev = ","; $RG = ","
                $RGLvl = ","; $Ext = ","; $DPType = ","; $DPPool = ","
            }
           
            # We are finally at LDEV Level 2 deep
            $l = 2
            break
        }
       
        "displayName" {
            $LUN += "," + $hash[1]
            break
        }
        "objectID" {
            if ($l -eq 2) {
            # Storage serial
                $SS = "," + $hash[1].Split('.')[2]
            # Storage type/model
                $ST = "," + $hash[1].Split('.')[1]
            }
            break
        }
       
        "emulation" {
            $Emul = "," + $hash[1]
            break
        }
       
        "commandDevice" {
            switch ($hash[1]) {
                "false" {$CMDDev = "," + "0"}
                "true" {$CMDDev = "," + "1"}
            }
            #$CMDDev = "," + $hash[1]
            break
        }
       
        "arrayGroupName" {
            $RG = "," + $hash[1]
            break
        }
       
        "raidType" {
            $RGLvl = "," + $hash[1]
            break
        }
       
        "consumedCapacityInKB" {
            $LUsed = "," + $hash[1].Replace(".", "")/1024
            break
        }
       
        "externalVolume" {
            $Ext = "," + $hash[1]
            break;
        }
       
        "dpType" {
            $DPType = "," + $hash[1]
            break
        }
       
        "dpPoolID" {
            $DPPool = "," + $hash[1]
            break
        }
    }  
}
 
# Must process final line as it was not created by the main loop
if ($LUN -ne "") {
    $LUNs += $LUN + $SS + $ST + $LUsed + $Emul + $RG + $RGLvl + $CMDDev + $Ext + $DPType + $DPPool
}
 
foreach ($wc in $WWNs) {
    foreach ($lc in $LUNs) {
        Add-Content $out_csv $Hst$OS$wc$lc
    }
}
 
Write-Host "Done."
