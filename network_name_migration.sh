#!/usr/bin/env bash -e

NM_DIR="/etc/NetworkManager/system-connections"
SYSTEMD_DIR="/etc/systemd/network"

# =================================================================
# IDEMPOTENCY CHECK: Skip if modern systemd link configurations exist
# =================================================================
if compgen -G "${SYSTEMD_DIR}/10-enp0s*.link" > /dev/null; then
    echo "* Network interface migration to enp* layout already completed. Skipping."
    exit 0
fi

mkdir -p "$NM_DIR" "$SYSTEMD_DIR"
COUNTER=0

# Safely loop through interfaces without running in a subshell
while read -r name status mac _; do
    
    # Ignore loopback and empty/malformed lines
    if [ "$name" == "lo" ] || [ -z "$mac" ]; then
        continue
    fi

    # Extract the current active IPv4 address to inspect the subnet
    IP_ADDR=$(ip -4 addr show dev "$name" | awk '/inet / {print $2}')

    # =================================================================
    # DYNAMIC SUBNET DETECT & INDEX ASSIGNMENT
    # =================================================================
    # Catch any interface holding a 192.168.56.xx IP address
    if [[ "$IP_ADDR" == *"192.168.56."* ]]; then
        INDEX=1
        NEVER_DEFAULT="never-default=true"
    # Catch your main NAT management network
    elif [[ "$IP_ADDR" == *"10.0.2."* ]]; then
        INDEX=0
        NEVER_DEFAULT="never-default=false"
    else
        # Fallback index tracking for extra interfaces
        INDEX=$COUNTER
        NEVER_DEFAULT="never-default=false"
        COUNTER=$((COUNTER + 1))
    fi

    # Define the target predictable interface layout
    NEW_NAME="enp0s${INDEX}"

    # =================================================================
    # LAYER A: NETWORKMANAGER KEYFILE CONFIGURATION
    # =================================================================
    NM_FILE="${NM_DIR}/${NEW_NAME}.nmconnection"

    cat << EOF > "$NM_FILE"
[connection]
id=${NEW_NAME}
type=ethernet
interface-name=${NEW_NAME}

[ethernet]
mac-address=${mac}

[ipv4]
method=auto
${NEVER_DEFAULT}

[ipv6]
method=auto
EOF

    chmod 600 "$NM_FILE"

    # =================================================================
    # LAYER B: PERSISTENT SYSTEMD HARDWARE MAPPING
    # =================================================================
    LINK_FILE="${SYSTEMD_DIR}/10-${NEW_NAME}.link"

    cat << EOF > "$LINK_FILE"
[Match]
MACAddress=${mac}

[Link]
Name=${NEW_NAME}
EOF

    echo "Mapped and generated: $name -> $NEW_NAME (IP: ${IP_ADDR:-None}, MAC: $mac)"

done < <(ip -brief link show)

# Reload the NetworkManager engine settings
echo "Applying new connection profiles..."
nmcli connection reload

# Clear out ALL legacy ifcfg scripts to bypass the Leapp upgrade block
if compgen -G "/etc/sysconfig/network-scripts/ifcfg-*" > /dev/null; then
    echo "Archiving old network scripts to /root/..."
    mv /etc/sysconfig/network-scripts/ifcfg-* /root/
else
    echo "No old ifcfg-* files found to clear."
fi