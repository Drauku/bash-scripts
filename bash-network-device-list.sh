#!/bin/bash

for i in $(ip link show | grep -o '^[0-9]: en[^:]*'); do
    iface=$(echo $i | cut -d: -f2);
    echo "Interface: $iface";
    path=$(readlink -f /sys/class/net/$iface/device);
    if [ -n "$path" ]; then
        pci_addr=$(basename "$path");
        echo "PCI Address: $pci_addr";
        lspci -s "$pci_addr";
    fi;
    echo "---";
done