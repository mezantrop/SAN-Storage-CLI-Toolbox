#!/bin/sh

# List all WWNS with additional info in a given Brocade fabric 
# v 0.3 
 
switch="192.168.187.223"
login="admin"
password="password"

# -----------------------------------------------------------------------------
fashion="../fashion/fashion"
awk="nawk"

# ----------------------------------------------------------------------------- 
usage() {
    echo "Usage:"
    echo " fab_wwns.sh <switch> <login> <password>"
    exit 1
}
  
# ----------------------------------------------------------------------------- 
[ "$#" -ne 3 ] && usage

switch="$1"
login="$2"
password="$3"


$fashion $switch $login $password "fabricshow" > /tmp/fabricshow.$switch.txt 2> /dev/null
($fashion $switch $login $password "nscamshow" 2> /dev/null && $fashion $switch $login $password "nsshow" 2> /dev/null) | 
    $awk -v t=$switch 'BEGIN {
                fshow="/tmp/fabricshow."t".txt"
                while (getline LINE < fshow) {fab[i++]=LINE}
                print "#; Port name; Node name; Switch name; DID; Port #; Loop #; FC addr; Type; Fabric port name; Aliases; Port Symb; Node Symb"
            }
     
            / ([NL])+   / {
 
                FS=" "
                d_cnt++
             
                type[d_cnt]=$1
                pid[d_cnt]=substr($2, 1, 6)
                split($0, wwns, ";")
                portname[d_cnt]=wwns[3]
                nodename[d_cnt]=wwns[4]
                 
                wwndid[d_cnt]=substr(pid[d_cnt], 0, 2)
                wwnport[d_cnt]=substr(pid[d_cnt], 3, 2)
                wwnloop[d_cnt]=substr(pid[d_cnt], 5, 2)
     
                decimal=0
                for(i=1; i<=2; i++) {
                    decimal*=16
                    hex=substr(wwnport[d_cnt], i, 1)
                    if (hex == "a") decimal+=10; else
                        if (hex == "b") decimal+=11; else
                            if (hex == "c") decimal+=12; else
                                if (hex == "d") decimal+=13; else
                                    if (hex == "e") decimal+=14; else
                                        if (hex == "f") decimal+=15; else
                                            decimal+=hex
                }
                wwnport10[d_cnt]=decimal
 
                for (sw in fab) {
                    split(fab[sw], switch, " ")
                    did=substr(switch[2], 5, 2)
 
                    if (did == wwndid[d_cnt]) {
                        switchname[d_cnt]=switch[6]
                        break
                    }
                }
 
            }
            / PortSymb: / {FS="\""; portsymb[d_cnt]=$2}
            / NodeSymb: / {FS="\""; nodesymb[d_cnt]=$2}
            / Port Index: / {FS=" "; if ($3 != "na") wwnport10[d_cnt]=$3}
            / Fabric Port Name: / {FS=" "; fabricportname[d_cnt]=$4}
            / Aliases: / {FS=":"; aliases=$2}
         
        END {
            for (c=1; c<=d_cnt; c++) {
                printf "%3d; %s; %s; %s; %s; %s; %s; %s; %s; %s; %s; %s; %s\n", c, portname[c], nodename[c], switchname[c], wwndid[c], wwnport10[c], wwnloop[c], pid[c], type[c], fabricportname[c], aliases[c], portsymb[c], nodesymb[c]
            }
             
        }'
 
rm /tmp/fabricshow.$switch.txt
