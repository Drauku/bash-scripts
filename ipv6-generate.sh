#!/bin/bash

printf "\nThis script generates a unique IPv6 address based on the current timestamp and machine-id.\n"

generate_ipv6() {

  read -rp "Enter IPv6 prefix (default fd00:1abc): " prefix
  prefix=${prefix:-fd00:1abc:}

  timestamp="$(date +%s%N)"

  uniqueid="$(cat /etc/machine-id)"

  hash=$(printf "$timestamp$uniqueid" | sha1sum)

  address=$(printf "$hash" | cut -c 1-24)

  tempfile=$(mktemp)
  echo "$address" > "$tempfile"

  formatted=$(awk 'BEGIN{OFS=FS=":"}{gsub(/..../,"&:")}1' "$tempfile")

  rm "$tempfile"

  echo "${prefix}${formatted%:}"

  }

address=$(generate_ipv6)

echo "\nUnique IPv6 Address: \n$address\n"
