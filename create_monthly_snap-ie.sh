#!/bin/bash
if [ $# -ne 1 ]; then
        echo "Usage: $0 volume_id"
        exit 1;
fi


export PATH=$PATH:/usr/local/bin/:/usr/bin

# Safety feature: exit script if error is returned, or if variables not set.
# Exit if a pipeline results in an error.
set -ue
set -o pipefail

## Automatic EBS Volume Snapshot Creation & Clean-Up Script
#
# Written by Casey Labs Inc. (https://www.caseylabs.com)
# Contact us for all your Amazon Web Services Consulting needs!
# Script Github repo: https://github.com/CaseyLabs/aws-ec2-ebs-automatic-snapshot-bash
#
# Additonal credits: Log function by Alan Franzoni; Pre-req check by Colin Johnson
#
#June 2016: modified by rahona be to suit only one disk at time.
#October 2018: monthly version

## Variable Declartions ##

# Get Instance Details
volume_id=$1
region=eu-west-1
#volume_list=$(aws ec2 describe-volumes --region eu-central-1 --query Volumes[].VolumeId --output text)
# Set Logging Options
logfile="/var/log/ebs-snapshot-monthly.log"
logfile_max_lines="5000"


## Function Declarations ##

# Function: Setup logfile and redirect stdout/stderr.
log_setup() {
    # Check if logfile exists and is writable.
    ( [ -e "$logfile" ] || touch "$logfile" ) && [ ! -w "$logfile" ] && echo "ERROR: Cannot write to $logfile. Check permissions or sudo access." && exit 1

    tmplog=$(tail -n $logfile_max_lines $logfile 2>/dev/null) && echo "${tmplog}" > $logfile
    exec > >(tee -a $logfile)
    exec 2>&1
}

# Function: Log an event.
log() {
    echo "[$(date +"%Y-%m-%d"+"%T")]: $*"
}

# Function: Confirm that the AWS CLI and related tools are installed.
prerequisite_check() {
	for prerequisite in aws wget; do
		hash $prerequisite &> /dev/null
		if [[ $? == 1 ]]; then
			echo "In order to use this script, the executable \"$prerequisite\" must be installed." 1>&2; exit 70
		fi
	done
}

# Function: Snapshot all volumes attached to this instance.
snapshot_volumes() {
		# Get the device description so we can easily tell which volume this is.
		device_name=$(aws ec2 describe-volumes --region $region --output=text --volume-ids $volume_id --query 'Volumes[0].{Devices:Tags[0].Value}')

		# Take a snapshot of the current volume, and capture the resulting snapshot ID
		snapshot_description="$device_name-backup-$(date +%Y-%m-%d)"

		snapshot_id=$(aws ec2 create-snapshot --region $region --output=text --description $snapshot_description --volume-id $volume_id --query SnapshotId)
		log "New snapshot is $snapshot_id"
	 
		#Add archive value	
	aws ec2 create-tags --region $region --resource $snapshot_id --tags Key=Archive,Value=$(date +%Y-%m-%d)
}
	
## SCRIPT COMMANDS ##

log_setup
prerequisite_check

snapshot_volumes
