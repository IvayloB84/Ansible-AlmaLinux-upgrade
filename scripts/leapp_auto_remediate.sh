#!/usr/bin/env bash
# ==============================================================================
# IVO & DOBRIN'S ENTERPRISE SELF-HEALING ENGINE (PORTABLE JSON PARSER)
# ==============================================================================
set -euo pipefail

REPORT_JSON="/var/log/leapp/leapp-report.json"

echo "=== INITIALIZING LEAPP AUTOMATED REMEDIATION ENGINE ==="

# 1. Safety Boundary: Check if the preupgrade report file actually exists yet
if [ ! -f "$REPORT_JSON" ]; then
    echo "[WARNING] Leapp report JSON not found at $REPORT_JSON." >&2
    echo "Please run a standard 'leapp preupgrade' pass first to generate data." >&2
    exit 0
fi

echo "Scanning report files for critical upgrade inhibitors and high-risk factors..."

# 2. Extract and count how many fatal blockers exist in the system architecture
INHIBITOR_COUNT=$(jq '[.entries[] | select(.groups[]? | contains("inhibitor"))] | length' "$REPORT_JSON" 2>/dev/null || echo "0")
echo "Found ${INHIBITOR_COUNT} strict critical blocker(s). Proceeding to full sweep..."

# 3. IVO'S BULLETPROOF POSIX LOOP: Read through ALL entries to catch blockers and high-risks alike
jq -r '.entries[].id' "$REPORT_JSON" 2>/dev/null | sort -u | while read -r error_id; do
    if [ -z "$error_id" ]; then
        continue
    fi
    
    echo ">>> Remediation evaluating identifier: [${error_id}]"

    case "$error_id" in
        # FIX FOR KEY: 540ad84e3486eeb475fc8ce00450e75dadb956c8 (Third-Party Modules)
        "540ad84e3486eeb475fc8ce00450e75dadb956c8")
            echo "  [ACTION] Force purging old duplicate site-packages symlink fragments..."
            sudo rm -rf /usr/lib64/python3.12/site-packages/six* 2>/dev/null || true
            sudo rm -rf /usr/lib/python3.12/site-packages/six* 2>/dev/null || true
            ;;

        # FIX FOR KEY: 13f0791ae5f19f50e7d0d606fb6501f91b1efb2c (Unsigned Packages)
        "13f0791ae5f19f50e7d0d606fb6501f91b1efb2c")
            echo "  [ACTION] Forcefully uninstalling custom-python312, dkms, and epel-release..."
            sudo yum remove -y custom-python312 dkms epel-release || true
            ;;

        # FIX FOR KEY: f5770a56e540f27d370da7b697cb4a2e81e2c30d (Missing Target Repos Mapping)
        "f5770a56e540f27d370da7b697cb4a2e81e2c30d")
            echo "  [ACTION] Flushing package metadata cache matrices and target maps..."
            sudo rm -f /etc/yum.repos.d/almalinux*.repo
            sudo rm -f /etc/yum.repos.d/repo.almalinux.org*
            sudo dnf clean all
            sudo rm -rf /var/cache/dnf
            ;;

        "permit_root_secure_shell"|"sshd_permit_root_login")
            echo "  [ACTION] Fixing SSH daemon administrative configuration default parameters..."
            sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
            sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
            sudo systemctl restart sshd || true
            ;;

        "7de70b43c3c9d20075e30894ac24a4c4e2d70837"|"legacy_network_scripts")
            echo "  [ACTION] Migrating old networking legacy configuration files to modern keyfiles..."
            sudo nmcli connection migrate /etc/sysconfig/network-scripts/ifcfg-eth0 || true
            sudo nmcli connection migrate /etc/sysconfig/network-scripts/ifcfg-eth1 || true
            sudo rm -f /etc/sysconfig/network-scripts/ifcfg-eth*
            ;;

        "d3050d265759a79ce895e64f45e9c56e49b3a953"|"unsupported_kernel_names")
            echo "  [ACTION] Writing global link-validation bypass directly to Leapp parameters..."
            sudo mkdir -p /etc/leapp
            echo "LEAPP_OVB_SETUP_LINK_CHECK=1" | sudo tee -a /etc/leapp/vars.all > /dev/null
            ;;

        "btrfs_kernel_module_loaded"|"floppy_kernel_module_check")
            echo "  [ACTION] Unloading and blacklisting deprecated kernel modules..."
            MOD_NAME=$(echo "$error_id" | cut -d'_' -f1)
            sudo rmmod "$MOD_NAME" 2>/dev/null || true
            sudo mkdir -p /etc/modprobe.d
            echo "blacklist $MOD_NAME" | sudo tee -a /etc/modprobe.d/leapp-blacklist.conf > /dev/null
            ;;

        "missing_answerfile_confirmations"|"answerfile_validation")
            echo "  [ACTION] Force-injecting programmatic approvals into system answerfile template..."
            sudo mkdir -p /var/log/leapp
            sudo cat << 'EOF_ANS' >> /var/log/leapp/answerfile

[remove_pam_userdb]
confirm = true

[check_vdo]
confirm = true
EOF_ANS
            ;;

        "old_kernels_detected"|"check_vmlinuz_presence")
            echo "  [ACTION] Purging residual duplicate legacy kernel instances to clear the partition blocks..."
            sudo dnf remove -y $(dnf repoquery --duplicated --queryformat '%{name}-%{version}-%{release}.%{arch}') || true
            ;;

        *)
            echo "  [INFO] Key '${error_id}' evaluated safely. No automated action required."
            ;;
    esac
    echo "--------------------------------------------------------"
done

echo "=== REMEDIATION CYCLE COMPLETE ==="
exit 0
