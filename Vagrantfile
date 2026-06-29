# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # =========================================================================
  # GLOBAL CONFIGURATION & AUTOMATED TRIGGERS (Applies to ALL defined VMs)
  # =========================================================================

  # 1. AUTOMATED BACKUP: Take a safety snapshot BEFORE any provisioning starts
  config.trigger.before :provision do |trigger|
    trigger.name = "Pre-Provision Safety Snapshot"
    trigger.info = "Backing up active VM state automatically before modification..."
    
    trigger.ruby do |env, machine|
      vbox_uuid = machine.id.to_s
      puts "=== [GLOBAL BACKUP] Freezing baseline state for hardware UUID: #{vbox_uuid} ==="
      
      # FIX: Changed --force to --uniquename Force to match VirtualBox 7.2 syntax
      system("VBoxManage snapshot #{vbox_uuid} take auto_pre_upgrade_backup --uniquename Force")
    end
  end

  # 2. AUTOMATED CLEANUP: Delete the snapshot AFTER provisioning completes
  config.trigger.after :provision do |trigger|
    trigger.name = "Post-Provision Cleanup"
    trigger.info = "Provisioning complete. Clearing temporary safety layers..."
    
    trigger.ruby do |env, machine|
      vbox_uuid = machine.id.to_s
      puts "=== [GLOBAL CLEANUP] Clearing temporary safety snapshot for hardware UUID: #{vbox_uuid} ==="
      
      # Clean up the snapshot on the hardware layer automatically
      system("VBoxManage snapshot #{vbox_uuid} delete auto_pre_upgrade_backup")
    end
  end

  config.vm.boot_timeout = 600 
  config.vm.synced_folder ".", "/vagrant", disabled: false

  # Global Provider Settings (applied to all machines regardless of box)
  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2         # Bumping to 2 CPUs significantly speeds up compilation
    vb.memory = 2048    # 2GB RAM prevents disk thrashing during DNF transactions

    vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
    vb.customize ["modifyvm", :id, "--nictype2", "virtio"]
    vb.customize ["modifyvm", :id, "--vram", "12"]
  end

  # AUTOMATED DRIVER FIX: Force kernel tools & VirtualBox modules to recompile on initial setup
  config.vm.provision "shell", inline: <<-SHELL
    echo "=== Running Native Guest Additions Recompile globally ==="
    sudo dnf install -y epel-release
    sudo dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r) gcc make elfutils-libelf-devel dkms
    if [ -f /sbin/rcvboxadd ]; then
      sudo /sbin/rcvboxadd setup || true
    fi
  SHELL

  # Global Python Setup Provisioning (Forces execution on every single boot phase)
  # config.vm.provision "shell", inline: "sudo mount -t vboxsf vagrant /vagrant || true; bash /vagrant/scripts/custom_python312_installation.sh", run: "always"

  # =========================================================================
  # INDIVIDUAL MACHINE DEFINITIONS
  # =========================================================================

  # --- VIRTUAL MACHINE: VM1 ---
  config.vm.define "vm1" do |vm1|
    vm1.vm.box = "almalinux/8"
    vm1.vm.hostname = "vm1.do1.lab"
    vm1.vm.network "private_network", ip: "192.168.56.100"
    vm1.vm.network "forwarded_port", guest: 80, host: 8080, auto_correct: true
  end 

  # --- VIRTUAL MACHINE: VM2 ---
  config.vm.define "vm2" do |vm2|
    vm2.vm.box = "almalinux/8"
    vm2.vm.hostname = "vm2.do1.lab"
    vm2.vm.network "private_network", ip: "192.168.56.101"
    vm2.vm.network "forwarded_port", guest: 80, host: 8081, auto_correct: true

    # TARGETED ANSIBLE EXECUTION FOR VM2
    vm2.vm.provision "ansible" do |ansible|
      ansible.playbook = "playbook_RH_migration_8_9.yml"
      ansible.raw_arguments = ["--flush-cache"]
    end
  end

end