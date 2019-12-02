# ------------------------------------------------------------------------------
# Check if a WWN is listed within Name service in Cisco MDS fabric
# ------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# zmey20000@yahoo.com wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return Mikhail Zakharov
# -----------------------------------------------------------------------------

# -- CHANGELOG -----------------------------------------------------------------
# 2019.11.29, v1.0,   Mikhail Zakharov <zmey20000@yahoo.com>, Initial release
# 2019.12.02, v1.0.1, Mikhail Zakharov <zmey20000@yahoo.com>, Cosmetic changes

# -- USAGE ---------------------------------------------------------------------
# mds_wwnlook.ps1 -user <user> -password <Secret1!> -target <address> -wwn <WWN>
#            [-ssh_command plink.exe] [-ssh_options -ssh -C -batch]
#
# If any of the mandatory arguments is not specifiec in command-line,
# it is requested interactively.
#
# WARNING! In both cases password is visible in plan text!

# ------------------------------------------------------------------------------

# Command line options
param (
    [string]$ssh_command = "plink.exe",
    [string]$ssh_options = "-ssh -C -batch",
    [Parameter(Mandatory=$true)][string]$user,
    [Parameter(Mandatory=$true)][string]$password,
    [Parameter(Mandatory=$true)][string]$target,
    [Parameter(Mandatory=$true)][string]$wwn
)

$cmd_sh_fcns = "sh fcns dat"
$cmd_sh_vsans= "sh vsan | i vsan"
$in_wwns = Import-Csv -Path $in_csv

# Get VSAN info from fabric
$vsans_data = &($ssh_command) $ssh_options.split() -pw $password $user@$target $cmd_sh_vsans 2> $null

# Parse VSAN IDs
$vsans = @()
foreach ($vsan_ln in $vsans_data -split "`n") {
    $vsans += ($vsan_ln -split '\s+')[1] | Select-String -notMatch ":" 
}

# Fetch name-server info for each VSAN
foreach ($vsan in $vsans) {
	$wwns = @()
    $ns_data = &($ssh_command) $ssh_options.split() -pw $password $user@$target $cmd_sh_fcns "vsan" $vsan "| i 0x" 2> $null

    foreach ($ns_ln in $ns_data -split "`n") {
        # Get FCID and WWN from NS 
        $nswwn = ($ns_ln -split "\s+")[0, 2]

        # Lookup the WWN in nameserver data dump
            if ($nswwn[1] -eq $wwn) {
                # write output to the CSV file
                $out_data = [string]$nswwn[1] + [string]$inwwn."Port" + [string]$vsan + [string]$nswwn[0]
                Write-Host "VSAN:", $vsan, "FCID:", $nswwn[0]
                break
            }
    }
}
