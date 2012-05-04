#
# Cookbook Name:: wt_netacuity
# Recipe:: default
#
# Copyright 2012, Webtrends
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

# create the install directory
directory node['wt_netacuity']['install_dir'] do
  owner "root"
  group "root"
  mode "0755"
  recursive true
  action :create
end

# pull the remote file only if we create the directory
remote_file "/tmp/NetAcuity_#{node['wt_netacuity']['version']}.tgz" do
  source "#{node['wt_netacuity']['download_url']}/NetAcuity_#{node['wt_netacuity']['version']}.tgz"
  mode "0644"
  subscribes :create, resources(:directory => node['wt_netacuity']['install_dir']), :immediately
end

# run the tar only if the new file is pulled down
execute "tar" do
  user  "root"
  group "root" 
  cwd node['wt_netacuity']['install_dir']
  command "tar zxf /tmp/#{tarball}"
  action :nothing
  subscribes :run, resources(:remote_file => "/tmp/NetAcuity_#{node['wt_netacuity']['version']}.tgz"), :immediately
end

# delete the gzip
execute "cleanup" do
  command "rm NetAcuity.tgz"
  cwd "/opt/NetAcuity"
  action :nothing
  only_if do File.exists?("/opt/NetAcuity/NetAcuity.tgz") end
  subscribes :run, resources(:execute => "unpack")
end

cookbook_file "netacuity-init" do
  path "/etc/init.d/netacuity"
  source "netacuity.init"
  owner "root"
  group "root"
  mode 00744
end

service "netacuity" do
  enabled true
  running true
  pattern "netacuity_server"
  supports :status => false, :restart => true, :reload => false
  action [ :enable, :start ]
end

template "netacuity-config" do
  path "#node['wt_netacuity']['install_dir']/server/netacuity.cfg"
  source "netacuity.cfg.erb"
  notifies :restart, resources(:service => "netacuity")
end