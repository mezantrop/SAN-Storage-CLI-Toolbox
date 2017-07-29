#!/bin/sh
 
# -----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# zmey20000@yahoo.com wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return Mikhail Zakharov
# -----------------------------------------------------------------------------

#
# Get and parse "zoneshow" from Brocade fabric switch
#
 
# -----------------------------------------------------------------------------
usage() {
    echo "Usage:"
    echo " zoneparse.sh <switch> <login> <password>"
    echo " zoneparse.sh zoneparse.cfg"
    exit 1
}
 
# -----------------------------------------------------------------------------
 
FASHION=../fashion/fashion
 
# -----------------------------------------------------------------------------
 
[ "$#" -ne 3 -a "$#" -ne 1 ] && usage
 
[ "$#" -eq 1 ] && . $1      # Read config-file
if [ "$#" -eq 3 ] ; then
    HOST="$1"
    LOGIN="$2"
    PASSWORD="$3"
fi
 
[ -z "$HOST" -o -z "$LOGIN" -o -z "$PASSWORD" ] && 
    echo "Error: Wrong credentials cpecified!" && usage
 
"$FASHION" "$HOST" "$LOGIN" "$PASSWORD" "zoneshow" | 
    tr '\t\n' ';' | tr -d ' ' | tr -s ';' '\n' | awk '
        BEGIN { print "D/E configuration;Type;Name;Member" }
 
        /Definedconfiguration:/ {
            cfg="Defined"
            next
        }
 
        /Effectiveconfiguration:/   {
            cfg="Effective"
            next
        }
 
 
        /alias:/    {
            r=1; type="alias"
            next
        }
 
        /cfg:/  {
            r=1; type="cfg"
            next
        }
         
        /zone:/ {
            r=1; type="zone"
            next
        }
     
 
        {
            if (r == 0)
                printf "%s;%s;%s;%s\n", cfg, type, name, $1
            else
                {
                    name=$1
                    r = 0
                }
        }
'
