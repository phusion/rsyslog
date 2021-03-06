#
# Cookbook Name:: rsyslog
# Recipe:: default
#
# Copyright 2009-2013, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

has_service_spec = !!node['rsyslog']['service_spec']
if !has_service_spec
  node.set['rsyslog']['service_spec'] = "service[#{node['rsyslog']['service_name']}]"
end

package 'rsyslog'
package 'rsyslog-relp' if node['rsyslog']['use_relp']

directory "#{node['rsyslog']['config_prefix']}/rsyslog.d" do
  owner 'root'
  group 'root'
  mode  '0755'
end

directory '/var/spool/rsyslog' do
  if node['rsyslog']['priv_seperation']
    owner node['rsyslog']['user']
    group node['rsyslog']['group']
  else
    owner 'root'
    group 'root'
  end
  mode  '0750'
end

# Our main stub which then does its own rsyslog-specific
# include of things in /etc/rsyslog.d/*
template "#{node['rsyslog']['config_prefix']}/rsyslog.conf" do
  source  'rsyslog.conf.erb'
  owner   'root'
  group   'root'
  mode    '0644'
  notifies :restart, node['rsyslog']['service_spec']
end

template "#{node['rsyslog']['config_prefix']}/rsyslog.d/50-default.conf" do
  source  '50-default.conf.erb'
  owner   'root'
  group   'root'
  mode    '0644'
  notifies :restart, node['rsyslog']['service_spec']
end

# syslog needs to be stopped before rsyslog can be started on RHEL versions before 6.0
if platform_family?('rhel') && node['platform_version'].to_i < 6
  service 'syslog' do
    action [:stop, :disable]
  end
elsif platform_family?('smartos', 'omnios')
  # syslog needs to be stopped before rsyslog can be started on SmartOS, OmniOS
  service 'system-log' do
    action :disable
  end
end

if platform_family?('omnios')
  # manage the SMF manifest on OmniOS
  template '/var/svc/manifest/system/rsyslogd.xml' do
    source 'omnios-manifest.xml.erb'
    owner 'root'
    group 'root'
    mode '0644'
    notifies :run, 'execute[import rsyslog manifest]', :immediately
  end

  execute 'import rsyslog manifest' do
    action :nothing
    command 'svccfg import /var/svc/manifest/system/rsyslogd.xml'
    notifies :restart, "service[#{node['rsyslog']['service_name']}]"
  end
end

if !has_service_spec
  if node['platform'] == 'ubuntu' && node['platform_version'].to_f >= 12.04
     service_provider = Chef::Provider::Service::Upstart
  else
     service_provider = nil
  end

  service node['rsyslog']['service_name'] do
    supports :restart => true, :reload => true, :status => true
    action   [:enable, :start]
    provider service_provider
  end
end
