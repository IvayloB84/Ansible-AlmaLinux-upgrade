# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.boot_timeout = 600 
  config.vm.synced_folder ".", "/vagrant"

  # Global Provider Settings (applied to all machines regardless of box)
  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2         # Bumping to 2 CPUs significantly speeds up compilation
    vb.memory = 2048    # 2GB RAM prevents disk thrashing during DNF transactions
    vb.default_nic_type = "virtio"
    vb.customize ["modifyvm", :id, "--vram", "12"]
  end

  # Reusable Bash Script String
  $install_python = <<-SHELL
    if command -v python3.12 >/dev/null 2>&1 || [ -f "/usr/bin/python3.12" ] || [ -f "/usr/local/bin/python3.12" ]; then
        echo "* Python 3.12 is already installed. Skipping setup."
    else
        echo "* Python 3.12 not found. Preparing system update..."
        yum clean all
        yum update -y
        systemctl daemon-reload
        
        echo "* Installing compilation building blocks and tools..."
        yum install -y wget openssl-devel bzip2-devel libffi-devel gcc make
        yum groupinstall -y "Development Tools"
        
        mkdir -p /tmp/rpms
        if [ -d "/vagrant" ] && ls /vagrant/*.rpm >/dev/null 2>&1; then
            cp /vagrant/*.rpm /tmp/rpms/
            echo "* Installing local RPM files (including Python 3.12)..."
            dnf localinstall -y /tmp/rpms/*.rpm
            ln -sf /usr/bin/python3.12 /usr/bin/python312
        else
            echo "[WARNING] No RPM files found in /vagrant folder to install!"
        fi
        
        gcc --version && python3.12 --version
    fi
  SHELL

  # Global Provisioning (Executes on all machines using the script above)
  config.vm.provision "shell", inline: $install_python, privileged: true, run: "always"

  # =========================================================================
  # MACHINE DEFINITIONS
  # =========================================================================

  config.vm.define "vm1" do |vm1|
    vm1.vm.box = "almalinux/8"
    vm1.vm.hostname = "vm1.do1.lab"
    vm1.vm.network "private_network", ip: "192.168.56.100", auto_config: false
    vm1.vm.network "forwarded_port", guest: 80, host: 8080, auto_correct: true
  end 

  config.vm.define "vm2" do |vm2|
    vm2.vm.box = "almalinux/8"
    vm2.vm.hostname = "vm2.do1.lab"
    vm2.vm.network "private_network", ip: "192.168.56.101", auto_config: false
    vm2.vm.network "forwarded_port", guest: 80, host: 8081, auto_correct: true
  end

  # =========================================================================
  # DYNAMIC ANSIBLE AUTO-RUN STRATEGY
  # =========================================================================
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "playbook_RH_migration_9_10.yml"
  end
end