# encoding: utf-8

# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION ||= "2"

Vagrant.require_version ">= 2.2.18"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.ssh.forward_agent = false
  config.ssh.forward_x11 = false
  config.ssh.keep_alive = true
  config.ssh.username = "vagrant"
  config.vm.box_check_update = false
  config.vm.communicator = "ssh"
end
