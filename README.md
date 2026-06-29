# RedHat-Based Enterprise Linux Based Distributions Major Version Upgrade Playbooks

This repository contains robust, production-ready Ansible playbooks designed to automate the major version upgrades of RedHat-based distributions (such as AlmaLinux, Rocky Linux, and RHEL) from **version 8 to 9** and **version 9 to 10**.

The solution has been developed and tested locally using **VirtualBox** and **Vagrant**, but it is adaptable to any virtual machine environment. It features streamlined play-level execution blocks, automated high-risk inhibitor mitigations, and an idempotent network naming migration sequence optimized for speed.

---

## ⚙️ Prerequisites & Infrastructure Notes

### 1. Python Compatibility & Environment Isolation
*   **Target Engine Requirements:** AlmaLinux/RHEL 8 natively includes Python 3.6, which is **not compatible** with modern Ansible core engines. You can find the exact compatibility matrix in the [official Ansible documentation](https://docs.ansible.com/projects/ansible-core/devel/reference_appendices/release_and_maintenance.html#ansible-core-target-node-python-support).
*   **Interpreter Overrides:** To bypass this constraint, the `ansible.cfg` file in this repository is explicitly hardcoded to target `ansible_python_interpreter=/usr/bin/python3.12`.
*   **RPM Package Handling:** GitHub restricts large binary uploads. You must place your own Python 3.12 RPM packages inside your project directory. Our global `$install_python` Vagrant script automatically scans your local path to run the compilation phase.

### 2. Idempotent Network Migration Strategy (`network_name_migration.sh`)
*   **Inhibitor Clearance:** Migrating from legacy `eth*` interface naming configurations to modern **NetworkManager keyfiles** is mandatory. The `leapp` pre-upgrade tool treats legacy network configuration configurations as a critical inhibitor, blocking the upgrade.
*   **Execution Optimization:** The included `network_name_migration.sh` script automates the transformation and maps hardware profiles directly to system links. 
*   **Playbook Guard Rules:** The pipeline features an automated `ansible.builtin.stat` task that checks for active system-link definitions before processing. This dynamically skips file transfers, uploads, and execution delays on all subsequent runs.
*   **Legacy Sweeping:** To fully pass the AlmaLinux 10 validation pass, the playbook includes a final cleaning command (`rm -f /etc/sysconfig/network`) to purge old configuration leftovers before the analysis runs.

### 3. Vagrant & VirtualBox Driver Requirements
*   **Driver Configuration:** If you are testing this locally using the provided `Vagrantfile`, ensure your network configuration uses a **paravirtualized network interface (virtio)**.
*   **Hardware Protections:** Avoid using *Intel PRO/1000* network adapters to bypass `e1000` driver dependency faults. The `Vagrantfile` automatically assigns `vb.default_nic_type = "virtio"` globally across your nodes.
*   **Capability Bypass:** The machine definitions utilize `auto_config: false` overrides on their private network bindings. This prevents Vagrant from crashing due to `configure_networks` capability failures during major OS level reboots.

### 4. High-Risk Warning Mitigations
*   **Unverified Package Signatures:** The custom-built local Python 3.12 RPMs leave unsigned signatures behind in the system’s RPM database. The playbook automatically appends the `unsupported_upgrade_unverified_packages` confirmation flag inside a consolidated answerfile copy template to allow a clean pass.
*   **Deprecated Graphics Stack:** AlmaLinux 10 drops legacy display servers. The playbook includes a proactive `dnf` task to purge all unneeded `Xorg` server and driver configurations right before triggering the upgrade checks.

---

## 📂 Playbook Breakdown

The repository contains two distinct playbook files. Because the upgrade steps between major versions differ significantly, they have been separated:

* **`playbook_RH_migration_8_9.yml`**: Handles the progressive upgrade from RHEL/AlmaLinux 8 to 9. This includes the mandatory legacy network migration steps.
* **`playbook_RH_migration_9_10.yml`**: Handles the upgrade from RHEL/AlmaLinux 9 to 10. Legacy network migration steps are included here but utilize speed optimizations, since the machine structure has changed.

### 🏗️ Advanced Structural Controls
To keep the codebase streamlined and clean for GitHub, the playbooks incorporate advanced Ansible workflow mechanisms:

*   **Unified Block Filtering:** Instead of applying duplicate conditional checks on every single task, the core migration tasks are grouped inside an optimization `block` driven by a singular `when: ansible_distribution_major_version == '9'` check. This significantly reduces playbook maintenance and line counts.
*   **Asynchronous Loop Tracking:** The heavy OS package compilation and download tasks use `async: 1800` with `poll: 0` paired with `ansible.builtin.async_status` and `no_log: true`. This silently processes gigabytes of AlmaLinux 10 package structures in the background while keeping the terminal interface completely clean and free of retry spam.
*   **Post-Upgrade Validation & Housekeeping:** Once the upgrade completes, the playbook automatically refreshes the fact engine, asserts that the running system major version equals `10`, and performs a cleanup to sweep away legacy `5.14.0` kernels, obsolete `leapp` dependencies, and deprecated `libdb` packages.

---

## 🔬 Architectural Breakthroughs & Forensic Discoveries (AlmaLinux 10 Pipeline)

### 1. Persistent Storage Partition & Boot Alignment
*   **SDA4 Target Architecture:** Discovered that specific Vagrant VirtualBox box templates dynamically target `/dev/sda4` as the underlying primary operating system root filesystem (`/`) during major package migration runs, while keeping `/boot` on `/dev/sda3`.
*   **Pre-emptive Boot Device Redirection:** Implemented a targeted `sed` block filter step inside the playbook to anchor the active GRUB boot tracking parameter arrays (`/boot/grub2/grub.cfg` and `/etc/default/grub`) directly to `sda4`, neutralizing the low-level rescue/emergency mode loop loops on restart.
*   **Dracut Hardware Module Injection:** Forcefully injected core VirtualBox storage controller driver modules (`ahci`, `ata_piix`) and block-aware management layers (`rootfs-block`) straight into the custom `99-lean-upgrade-size.conf` configuration profile. This guarantees the initramfs upgrade environment retains total physical sector visibility upon hardware reboots.

### 2. Forensic Resolution of `adjust_local_repos` Linter Gate
*   **The Symptom:** Leapp pre-upgrade or upgrade processes terminated abruptly during the `TargetTransactionCheck` execution phase with a fatal exit code reporting: `leapp.workflow.TargetTransactionCheck.adjust_local_repos: Missing required information to proceed!`.
*   **The Root Cause:** High-efficiency playbook cleaning steps completely swept away the native repository definition tracks (`/etc/yum.repos.d/almalinux*.repo`) to prevent upgrade conflicts. However, Leapp's internal mapping actors require active local repository structures to run source-to-target schema matrix checks. Wiping the directory left an absolute metadata discovery void.
*   **The Remediation:** Modified the staging process to force a native package re-installation (`dnf reinstall -y almalinux-release`) right after the purge blocks. This fully restores the clean version 9 base tracking maps, providing complete structural visibility to the linter before the upgrade pass initiates.

### 3. Real-Time Telemetry and Automated Remediation
*   **YAML Callback Enhancements:** Enforced `result_format = yaml` paired with `stdout_callback = default` inside `ansible.cfg` to discard messy horizontal JSON text blocks and stream pristine, scannable vertical reports.
*   **Live Storage Monitoring:** Integrated pre-and-post cleanup checkpoints running `df -h` that automatically display storage allocation arrays directly in the terminal, proving an aggressive reclamation shield successfully swept away 1.0 GB of technical debt, stale caches, and unneeded dependencies.
*   **Integrated Summary Matrix:** Embedded a custom Python script snippet into the workflow that extracts data from `/var/log/leapp/leapp-report.json` and prints a high-visibility status board directly onto the terminal dashboard, rendering critical inhibitors and risk layers black-on-white.
*   **Dynamic POSIX Self-Healing Script:** Optimized `leapp_auto_remediate.sh` to leverage standard environments (`#!/usr/bin/env bash`) and strict loop parameters to automatically pull all high-and-medium risk identifier keys, forcefully dropping duplicate libraries or unsigned RPMs on the fly.


## 🚀 Getting Started with Vagrant

If you want to test the progressive upgrade path in an isolated sandbox, a complete classic Vagrant multi-machine environment is pre-configured.

### 1. Host Preparation
Ensure you have **VirtualBox**, **Vagrant**, and **Ansible** installed on your host system.

### 2. Add Local Custom Binaries
Drop your Python 3.12 RPM packages into the root repository directory. The `Vagrantfile`'s global `$install_python` string will automatically scan this folder and perform a local `dnf` installation on boot.

### 3. Spin Up and Provision the Nodes
To spin up a specific virtual machine (e.g., `vm2`) and trigger the automated upgrade pipeline, execute:

```bash
# Boot the machine (Initializes on AlmaLinux base images)
vagrant up vm2

# Execute the targeted Ansible migration playbook pipeline
vagrant provision vm2
```

### ⏱️ Important Execution & Monitoring Notes

*   **Resource Allocation:** Major operating system migrations are resource-heavy. It is highly recommended to allocate at least **2 vCPUs** and **2048 MB RAM** inside your provider block to speed up package extraction and `dracut` initramfs compilation.
*   **Terminal Behavior:** Because the playbook utilizes `no_log: true` on the tracking blocks, your terminal will remain clean and static during the background download loop. It will not flood your screen with retry alerts.
*   **Live Progress Tracking:** You can easily monitor the active package installation and migration tasks in real-time by opening a separate terminal and running:
    ```bash
    vagrant ssh vm2 -c "sudo tail -f /var/log/leapp/leapp-upgrade.log"
    ```
*   **Reboot Handshake Safety:** During the final reboot phase, the network socket layer can experience banner exchange connection timeouts. The playbook incorporates an explicit `delay: 45` and `connect_timeout: 30` parameter on the connection handler to ensure Vagrant and Ansible recover their connection paths safely after the AlmaLinux 10 kernel loads.

---

## 🛠️ Environment Specifications

The solution was successfully built and verified using the following local development environment:

### Ansible Configuration

```text
$ ansible --version
ansible [core 2.19.4]
  config file = /path/to/project/ansible.cfg
  configured module search path = ['/path/to/project/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  ansible collection location = /path/to/project/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible
  python version = 3.13.5 (main, May  5 2026, 21:05:52) [GCC 14.2.0] (/usr/bin/python3)
  jinja version = 3.1.6
  pyyaml version = 6.0.2 (with libyaml v0.2.5)

```

### Host OS Details

```text
$ cat /etc/os-release
PRETTY_NAME="Debian GNU/Linux 13 (trixie)"
NAME="Debian GNU/Linux"
VERSION_ID="13"
VERSION="13 (trixie)"
VERSION_CODENAME=trixie
DEBIAN_VERSION_FULL=13.5

```

### Hypervisor & Environment Tools

* **VirtualBox Version:** `7.2.10r174163`
* **Vagrant Version:** `2.4.9`