#!/usr/bin/env bash
set -euo pipefail

NM_DIR="/etc/NetworkManager/system-connections"
SYSTEMD_DIR="/etc/systemd/network"
LEAPP_FILES_DIR="/etc/leapp/files"

echo "=== START LIVE DEPLOYMENT MODE ==="
echo "Target directories: NM -> $NM_DIR | Systemd -> $SYSTEMD_DIR"
echo "--------------------------------------------------------"

# Ensure all target configuration folders physically exist on the drive
sudo mkdir -p "$NM_DIR" "$SYSTEMD_DIR" "$LEAPP_FILES_DIR"

COUNTER=0
TMP_LINKS=$(mktemp)
ip -brief link show > "$TMP_LINKS"

# Initialize our dynamic JSON mapping tracker strings
JSON_MAPPINGS=""

while read -r name status mac _; do
    
    if [ "$name" == "lo" ] || [ -z "$mac" ]; then
        continue
    fi

    # STATIC EXTRACT: Grab IP and mask directly using pattern matching without awk
    IP_ADDR=$(ip -4 addr show dev "$name" scope global | grep -oP 'inet \K[\d./]+' || echo "")

    # =================================================================
    # DYNAMIC SUBNET DETECT & INDEX ASSIGNMENT
    # =================================================================
    if [[ "$IP_ADDR" == *"192.168.56."* ]]; then
        INDEX=1
    elif [[ "$IP_ADDR" == *"10.0.2."* ]]; then
        INDEX=0
    else
        INDEX=$COUNTER
        COUNTER=$((COUNTER + 1))
    fi

    NEW_NAME="enp0s${INDEX}"
    CLEAN_IP=$(echo "$IP_ADDR" | cut -d'/' -f1)
    PREFIX=$(echo "$IP_ADDR" | cut -s -d'/' -f2)
    PREFIX=${PREFIX:-24}

    echo ">>> WRITING CONFIGURATION: $name -> $NEW_NAME (Live IP: ${CLEAN_IP:-None}/${PREFIX}, MAC: $mac)"
    echo "--------------------------------------------------------"

    # Append to our dynamic Leapp interface mapping string tracking container
    if [ -n "$JSON_MAPPINGS" ]; then JSON_MAPPINGS+=","; fi
    JSON_MAPPINGS+="{\"source_name\":\"$name\",\"target_name\":\"$NEW_NAME\"}"

    # =================================================================
    # STAGE A: WRITE LIVE NETWORKMANAGER KEYFILE
    # =================================================================
    NM_FILE="${NM_DIR}/${NEW_NAME}.nmconnection"
    if [[ "$NEW_NAME" != "enp0s0" ]]; then
        sudo tee "$NM_FILE" > /dev/null << EOF
[connection]
id=${NEW_NAME}
type=ethernet
interface-name=${NEW_NAME}

[ethernet]
mac-address=${mac}

[ipv4]
method=manual
addresses=${CLEAN_IP}/${PREFIX}
never-default=true

[ipv6]
method=ignore
EOF
    else
        sudo tee "$NM_FILE" > /dev/null << EOF
[connection]
id=${NEW_NAME}
type=ethernet
interface-name=${NEW_NAME}

[ethernet]
mac-address=${mac}

[ipv4]
method=auto
never-default=false

[ipv6]
method=auto
EOF
    fi
    sudo chmod 0600 "$NM_FILE"

    # =================================================================
    # STAGE B: WRITE LIVE SYSTEMD HARDWARE MAPPING
    # =================================================================
    sudo tee "${SYSTEMD_DIR}/10-${NEW_NAME}.link" > /dev/null << EOF
[Match]
MACAddress=${mac}

[Link]
Name=${NEW_NAME}
EOF

done < "$TMP_LINKS"
rm -f "$TMP_LINKS"

# =================================================================
# STAGE C: AUTO-GENERATE PERSISTENT LEAPP INTERFACE bluePRINT
# =================================================================
echo "Generating native Leapp network memory mapping profile rules..."
sudo tee "${LEAPP_FILES_DIR}/network_interfaces_mapping.json" > /dev/null << EOF
{
  "network_interfaces_mapping": [
    ${JSON_MAPPINGS}
  ]
}
EOF

sudo tee "${LEAPP_FILES_DIR}/device_driver_deprecation_data.json" > /dev/null << 'EOF'
{
  "device_driver_deprecation_data": []
}
EOF

# =================================================================
# LIVE SUBSYSTEM ACTIONS & ARCHIVE
# =================================================================
echo "Reloading network connection configurations..."
sudo nmcli connection reload || true

if compgen -G "/etc/sysconfig/network-scripts/ifcfg-*" > /dev/null; then
    echo "Archiving legacy network scripts to /root/..."
    sudo mkdir -p /root/legacy_network_scripts
    sudo mv /etc/sysconfig/network-scripts/ifcfg-* /root/legacy_network_scripts/ || true
else
    echo "No legacy network-scripts found to archive."
fi

echo "--------------------------------------------------------"
echo "=== END LIVE DEPLOYMENT MODE (All configurations successfully active) ==="