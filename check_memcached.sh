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

#aws cloudwatch get-metric-statistics --metric-name BytesUsedForCacheItems --namespace AWS/ElastiCache --start-time `date -u '+%FT%TZ' -d '1 mins ago'` --end-time `date -u '+%FT%TZ'` --period 60 --statistics Maximum --dimensions Name=CacheClusterId,Value=suoniamo


# Get Instance Details
cluster_id=$1
logfile="/var/log/elasticache.log"
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

#Check memcached
check_memcached() {
occupy=$(aws cloudwatch get-metric-statistics --metric-name BytesUsedForCacheItems --namespace AWS/ElastiCache --start-time `date -u '+%FT%TZ' -d '1 mins ago'` --end-time `date -u '+%FT%TZ'` --period 60 --statistics Maximum --dimensions Name=CacheClusterId,Value=$cluster_id --query Datapoints[].Maximum --output text)
log "$cluster_id has $occupy bytes occupied"
}

#Reboot memcached
reboot() {
if (( $(echo "$occupy > 400000000" |bc -l) )); then
reboot=$(aws elasticache reboot-cache-cluster --cache-cluster-id $cluster_id --cache-node-ids-to-reboot 0001)
log "$cluster_id rebooted. Here is the log $reboot"
else
log "$cluster_id is fine, not rebooting"
fi
}

## SCRIPT COMMANDS ##

log_setup
prerequisite_check
check_memcached
reboot
