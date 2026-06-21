#!/usr/bin/env bash -e

NM_DIR="/etc/NetworkManager/system-connections"
SYSTEMD_DIR="/etc/systemd/network"

# =================================================================
# IDEMPOTENCY CHECK: Skip if configuration has already been applied
# =================================================================
if [ -f "${SYSTEMD_DIR}/10-enp0s0.link" ] || [ -f "${SYSTEMD_DIR}/10-enp0s1.link" ]; then
    echo "* Network interface migration already completed. Skipping configuration."
    exit 0
fi

mkdir -p "$NM_DIR" "$SYSTEMD_DIR"

# Track interface sequence order safely using a Process Substitution 
# This prevents the while loop from running in a subshell
COUNTER=0

while read -r name status mac _; do
    
    # 1. Broad Idempotent Filter: Ignore loopback and empty mac rows
    if [ "$name" == "lo" ] || [ -z "$mac" ]; then
        continue
    fi

    # 2. Assign indexes based on actual IP subnet presence to guarantee accuracy
    # Check if the interface currently holds the 192.168.56.x network
    if ip addr show dev "$name" | grep -q "192.168.56."; then
        INDEX=1
    # Check if it holds the 10.0.2.x network
    elif ip addr show dev "$name" | grep -q "10.0.2."; then
        INDEX=0
    else
        # Fallback to sequential index if IPs aren't active yet
        INDEX=$COUNTER
        COUNTER=$((COUNTER + 1))
    fi

    # 3. Define the deterministic target interface identity
    NEW_NAME="enp0s${INDEX}"

    # =================================================================
    # LAYER A: NETWORKMANAGER KEYFILE CONFIGURATION
    # =================================================================
    NM_FILE="${NM_DIR}/${NEW_NAME}.nmconnection"

    # Force 192.168.56.x (INDEX 1) to never be the default internet gateway
    if [ "$INDEX" -eq 1 ]; then
        IPV4_METHOD="auto"
        NEVER_DEFAULT="never-default=true"
    else
        IPV4_METHOD="auto"
        NEVER_DEFAULT="never-default=false"
    fi

    cat << EOF > "$NM_FILE"
[connection]
id=${NEW_NAME}
type=ethernet
interface-name=${NEW_NAME}

[ethernet]
mac-address=${mac}

[ipv4]
method=${IPV4_METHOD}
${NEVER_DEFAULT}

[ipv6]
method=auto
EOF

    # Fix secure file permissions required by NetworkManager
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

    echo "Mapped and generated: $name -> $NEW_NAME (MAC: $mac, Mode: Index ${INDEX})"

# The syntax below (< <(command)) keeps the loop in the main shell process
done < <(ip -brief link show)

# Reload the NetworkManager engine configuration tables
echo "Applying new connection profiles..."
nmcli connection reload

# Check if any ifcfg files actually exist before trying to move them
# if compgen -G "/etc/sysconfig/network-scripts/ifcfg-*" > /dev/null; then
#     echo "Archiving old network scripts to /root/..."
#     mv /etc/sysconfig/network-scripts/ifcfg-* /root/
# else
#     echo "No old ifcfg-* files found to archive. Skipping and continuing..."
# fi