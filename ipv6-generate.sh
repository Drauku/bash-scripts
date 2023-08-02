#!/bin/bash

timestamp="$( date +%s%N )";

uniqueid="$( cat /etc/machine-id )";

hashcode=$( printf ${timestamp}${uniqueid} | sha1sum )

output="$( printf ${hashcode} | cut -c 31- )"

ipv6_formated="$( awk 'BEGIN{OFS=FS=","}{gsub(/..../,"&:",$2)}1' )"

printf "Unique IPv6 Address Prefix based on 'machine-id' and current stimestamp:\n $p::/64" $ipv6_formated
