require "json"

CONFIG_FILE = File.join(__dir__, "vm.json")
abort "vm.json not found. Run .\\create-vm.ps1 first." unless File.exist?(CONFIG_FILE)
spec = JSON.parse(File.read(CONFIG_FILE))

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.box_check_update = false
    config.vm.boot_timeout = 600
  config.vm.hostname = spec["name"]
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider "virtualbox" do |vb|
    vb.name         = spec["name"]
    vb.cpus         = spec["cpus"]
    vb.memory       = spec["memory"]
    vb.linked_clone = true
  end
end