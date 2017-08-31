#!/bin/sh

# -----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# zmey20000@yahoo.com wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return Mikhail Zakharov
# -----------------------------------------------------------------------------

# simmatch.sh - Scan IBM SVC/Storwize system for "SCSI ID Mismatches"
# 2017.08.31    v1.0

delim=","						# Main delimiter
delim2=";"						# Second layer delimiter
fashion="../fashion/fashion"	# fashion SSH wrapper. Comment/uncomment the
							# appropriate lines below if you want pure SSH

lshostvdiskmap="lshostvdiskmap -nohdr -delim $delim"

# ----------------------------------------------------------------------------- 
usage() {
    echo "Usage:"
    echo " simmatch.sh <target> <user> <password>"
    exit 1
}
  
# ----------------------------------------------------------------------------- 
[ "$#" -ne 3 ] && usage

target="$1"
user="$2"
password="$3"

awk="gawk"						# We need gawk to do the stuff

# Uncomment ssh and comment fashion if you like
#ssh "$user"@"$target" "$lshostvdiskmap" | $awk -F "$delim" -v d2=$delim2 '
$fashion "$target" "$user" "$password" "$lshostvdiskmap" | 
	$awk -F "$delim" -v d2=$delim2 '
{ 
	# Put all records into an array
	for (f = 1; f <= NF; f++)
		dm[NR, f] = $f
	dm[NR, NF + 1] = 0					# Mapping count
	dm[NR, NF + 2] = ""					# SCSI ID List
}

END {
	OFS = FS

	for (l = 1; l <= NR; l++)
		for (l1 = 1; l1 <= NR; l1++)
			if (dm[l, 4] == dm[l1, 4]) {
				dm[l, NF + 1] += 1
				dm[l, NF + 2] = dm[l, NF + 2] dm[l1, 3] OFS
			}

	# Pack SCSI ID List
	for (l = 1; l <= NR; l++)
		if (dm[l, 9] > 1) {
			len_sidlst = split(dm[l, NF + 2], sidlst)

			# get unique SCSI IDs only
			delete usidlst
			for (le = 1; le <= len_sidlst; le++)
				usidlst[sidlst[le]]++

			# Save unique SCSI IDs back to the list
			delete dm[l, NF + 2]
			for (sid in usidlst)
				if (sid != "")
					dm[l, NF + 2] = dm[l, NF + 2] sid d2
		}

	# Print out report
	print "Host ID", "Host Name", "SCSI ID", "Vdisk ID",\
		"Vdisk Name", "Vdisk UID", "IO Group ID",\
		"IO Group Name", "Mapping count", "SCSI ID List"

	for (l = 1; l <= NR; l++)
		if (split(dm[l, NF + 2], sidlst, d2) > 2) {
			for (f = 1; f < NF + 2; f++)
				printf dm[l, f] OFS
			# Ugly strip of the last "d2" occurrence
			printf substr(dm[l, NF + 2], 1, length(dm[l, NF + 2]) - 1)"\n"
		}
} 
'
