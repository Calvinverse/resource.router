# frozen_string_literal: true

#
# Cookbook Name:: resource_router
# Recipe:: default
#
# Copyright 2017, P. van der Velde
#

# Always make sure that apt is up to date
apt_update 'update' do
  action :update
end

#
# Include the local recipes
#

include_recipe 'resource_router::firewall'

include_recipe 'resource_router::consul'
include_recipe 'resource_router::meta'
include_recipe 'resource_router::network'
include_recipe 'resource_router::provisioning'
