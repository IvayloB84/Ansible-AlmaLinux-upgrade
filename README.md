
---

# RedHat-Based Enterprise Linux Based Distributions Major Version Upgrade Playbooks

This repository contains basic Ansible playbooks designed to automate the major version upgrades of RedHat-based distributions (such as AlmaLinux, Rocky Linux, and RHEL) from **version 8 to 9** and **version 9 to 10**.

The solution has been developed and tested locally using **VirtualBox** and **Vagrant**, but it is adaptable to any virtual machine environment.

---

## ⚙️ Prerequisites & Infrastructure Notes

### 1. Python Compatibility (`ansible.cfg`)

* AlmaLinux/RHEL 8 natively includes Python 3.6, which is **not compatible** with Ansible core 2.17.x and above. You can find the exact compatibility matrix in the [official Ansible documentation](https://docs.ansible.com/projects/ansible-core/devel/reference_appendices/release_and_maintenance.html#ansible-core-target-node-python-support).
* To bypass this, the `ansible.cfg` in this repo is configured to use a minimum of `ansible_python_interpreter=/usr/bin/python3.12`.
* **Action Required:** GitHub restricts large file uploads, so you must upload your own Python 3.12 RPM package to your environment and update the `custom_python3.12_install.sh` script to reflect your specific package version.

### 2. Network Migration (`network_name_migration.sh`)

* Migrating from legacy `eth*` interface naming configurations to modern **NetworkManager keyfiles** is mandatory. The `leapp` pre-upgrade check treats legacy network configurations as a critical inhibitor, blocking the upgrade.
* The included `network_name_migration.sh` shell script successfully automates the migration, renaming, and deletion of legacy interfaces.

### 3. Vagrant & VirtualBox Driver Requirements

* If you are testing this locally using the provided `Vagrantfile`, ensure your network configuration uses a **paravirtualized network interface (virtio)**.
* Avoid using the *Intel PRO/1000* network adapter, as the `leapp` process will throw a fatal error regarding the `e1000` driver.

---

## 📂 Playbook Breakdown

The repository contains two distinct playbook files. Because the upgrade steps between major versions differ significantly, they have been separated:

* **`playbook_HR_migration_8_to_9.yml`**: Handles the upgrade from RHEL/AlmaLinux 8 to 9. This includes the mandatory legacy network migration steps.
* **`playbook_HR_migration_9_to_10.yml`**: Handles the upgrade from RHEL/AlmaLinux 9 to 10. Legacy network migration steps are omitted here as they are no longer necessary.

---

## 🚀 Getting Started with Vagrant

If you want to test the upgrade path in an isolated sandbox, a complete Vagrant environment is pre-configured.

1. Ensure you have **VirtualBox**, **Vagrant**, and **Ansible** installed on your host machine.
2. Drop your Python 3.12 RPM package into the directory and update `custom_python3.12_install.sh`.
3. Spin up the environment:

```bash
vagrant up

```


4. Run the desired Ansible playbook to initiate the upgrade.

> ⏱️ **Note on Execution Time:** Depending on your VM configuration, the entire upgrade process might take up to **45 minutes**, as outlined in the Ansible playbooks. You can follow the progress if you open the Virtualbox gui. 

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
ID=debian
HOME_URL="https://www.debian.org/"
SUPPORT_URL="https://www.debian.org/support"
BUG_REPORT_URL="https://bugs.debian.org/"

```

### Hypervisor & Environment Tools

* **VirtualBox Version:** `7.2.10r174163`
* **Vagrant Version:** `2.4.9`