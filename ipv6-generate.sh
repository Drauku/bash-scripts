#!/bin/bash

generate_ipv6() {
  timestamp="$(date +%s%N)"
  uniqueid="$(cat /etc/machine-id)"
  
  hash=$(printf "$timestamp$uniqueid" | sha1sum)
  address=$(printf "$hash" | cut -c 1-32)
  
  formatted=$(awk 'BEGIN{OFS=FS=":"}{gsub(/..../,"&:")}1' <<< "$address")

  prefix="fd00:1abc:"

  echo "$prefix$formatted"
}

address=$(generate_ipv6)

echo "Unique IPv6 Address based on 'machine-id' and current timestamp: $address"
