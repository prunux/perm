#!/bin/bash

# Implement an Dynamic DNS System as described here
# https://nmbgeek.com/blog/dynamic-dns-updating-service-with-route-53-linux/
#
# Author: Roman Plessl
# License: GPLv3

# (optional) You might need to set your PATH variable at the top here
# depending on how you run this script
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Hosted Zone ID e.g. BJBK35SKMM9OE
ZONEID="##ZONEID##"

# The CNAME you want to update e.g. hello.example.com
RECORDSET="##YOURDOMAINTOUPDATE##"

# The Time-To-Live of this recordset
TTL=300

# Change this if you want
COMMENT="`date` Updated with dynamic-dns script and AWS CLI"

# Change to AAAA if using an IPv6 address.  You must also update dig command in IP variable removing the -4 option.
TYPE="A"

# Get Record set IP from Route 53
DNSIP="$(
   aws route53 list-resource-record-sets \
      --hosted-zone-id "$ZONEID" --start-record-name "$RECORDSET" \
      --start-record-type "$TYPE" --max-items 1 \
      --output json | jq -r \ '.ResourceRecordSets[].ResourceRecords[].Value'
)"

# Get the external IP address from OpenDNS. Remove -4 for IPv6
IP=`dig -4 +short myip.opendns.com @resolver1.opendns.com`

# Check that IP is valid
function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

if ! valid_ip $IP ; then
    echo `date`" Invalid IP address $IP Check dig command."
    exit 1
fi

# Check if the IP has changed and if so create JSON string for updating.
if [ "$IP" == "$DNSIP" ] ; then
    echo `date`" IP is still $IP. Exiting"
    exit 0
else
    echo `date`" IP has changed from $DNSIP to $IP"
    TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
    cat > ${TMPFILE} << EOF
    {
      "Comment":"$COMMENT",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "ResourceRecords":[
              {
                "Value":"$IP"
              }
            ],
            "Name":"$RECORDSET",
            "Type":"$TYPE",
            "TTL":$TTL
          }
        }
      ]
    }
EOF

    # Update the Hosted Zone record
    aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONEID \
        --change-batch file://"$TMPFILE" \
		--query '[ChangeInfo.Comment, ChangeInfo.Id, ChangeInfo.Status, ChangeInfo.SubmittedAt]' \
		--output text

    # Clean up
    rm $TMPFILE
fi