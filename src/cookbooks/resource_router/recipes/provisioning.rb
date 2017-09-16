# frozen_string_literal: true

#
# Cookbook Name:: resource_router
# Recipe:: provisioning
#
# Copyright 2017, P. van der Velde
#

#
# INSTALL DOS2UNIX
#

apt_package 'dos2unix' do
  action :install
end

#
# INSTALL PWGEN
#

apt_package 'pwgen' do
  action :install
end

#
# CONFIGURE THE PROVISIONING SCRIPT
#

# Create the provisioning script
file '/etc/init.d/provision.sh' do
  action :create
  content <<~BASH
    #!/bin/bash

    function getEth0Ip {
      local _ip _line
      while IFS=$': \t' read -a _line ;do
          [ -z "${_line%inet}" ] &&
            _ip=${_line[${#_line[1]}>4?1:2]} &&
            [ "${_ip#127.0.0.1}" ] && echo $_ip && return 0
        done< <(LANG=C /sbin/ifconfig eth0)
    }

    function setHostName {
      # Generate a 16 character password
      POSTFIX=$(pwgen --no-capitalize 16 1)

      NAME="cvrouter-${RESOURCE_VERSION_MAJOR}-${RESOURCE_VERSION_MINOR}-${RESOURCE_VERSION_PATCH}-${POSTFIX}"
      sudo hostnamectl set-hostname $NAME
    }

    FLAG="/var/log/firstboot.log"
    if [ ! -f $FLAG ]; then

      setHostName

      IPADDRESS=$(getEth0Ip)

      #
      # CREATE MACHINE SPECIFIC CONFIGURATION FILES
      #
      # Create '/etc/consul/conf.d/connections.json'
      echo "{ \\"advertise_addr\\": \\"${IPADDRESS}\\", \\"bind_addr\\": \\"${IPADDRESS}\\" }"  > /etc/consul/conf.d/connections.json

      #
      # MOUNT THE DVD WITH THE CONFIGURATION FILES
      #
      if [ ! -d /mnt/dvd ]; then
        mkdir /mnt/dvd
      fi
      mount /dev/dvd /mnt/dvd

      #
      # CONFIGURE SSH
      #
      # If the allow SSH file is not there, disable SSH in the firewall
      if [ ! -f /mnt/dvd/allow_ssh.json ]; then
        ufw deny 22
      fi

      #
      # CONSUL CONFIGURATION
      #
      cp -a /mnt/dvd/consul/consul_region.json /etc/consul/conf.d/region.json
      dos2unix /etc/consul/conf.d/region.json

      cp -a /mnt/dvd/consul/consul_secrets.json /etc/consul/conf.d/secrets.json
      dos2unix /etc/consul/conf.d/secrets.json

      cp -a /mnt/dvd/consul/client/consul_client_location.json /etc/consul/conf.d/location.json
      dos2unix /etc/consul/conf.d/location.json

      #
      # UNBOUND CONFIGURATION
      #
      cp -a /mnt/dvd/unbound/unbound_zones.conf /etc/unbound.d/unbound_zones.conf
      dos2unix /etc/unbound.d/unbound_zones.conf

      #
      # UNMOUNT DVD
      #
      umount /dev/dvd
      eject -T /dev/dvd

      #
      # ENABLE SERVICES
      #
      sudo systemctl enable unbound.service

      # The next line creates an empty file so it won't run the next boot
      touch $FLAG

      # restart the machine so that all configuration settings take hold
      sudo shutdown -r now
    else
      echo "Provisioning script ran previously so nothing to do"
    fi
  BASH
  mode '755'
end

# Create the service that is going to run the script
file '/etc/systemd/system/provision.service' do
  action :create
  content <<~SYSTEMD
    [Unit]
    Description=Provision the environment
    Requires=network-online.target
    After=network-online.target

    [Service]
    Type=oneshot
    ExecStart=/etc/init.d/provision.sh
    RemainAfterExit=true
    EnvironmentFile=-/etc/environment

    [Install]
    WantedBy=network-online.target
  SYSTEMD
end

# Make sure the service starts on boot
service 'provision.service' do
  action [:enable]
end
