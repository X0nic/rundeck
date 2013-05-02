#
# Cookbook Name:: wt_portfolio_manager
# Author: Toby Mosby(<toby.mosby@webtrends.com>)
# Recipe:: default
#
# Copyright 2012, Webtrends
#
# All rights reserved - Do Not Redistribute
# This recipe installs the Portfolio MC IIS app

if ENV["deploy_build"] == "true" then
  log "The deploy_build value is true so un-deploying first"
  include_recipe "ms_dotnet4::regiis"
  include_recipe "wt_portfolio_manager::uninstall"
else
  log "The deploy_build value is not set or is false so we will only update the configuration"
end

#Properties
install_dir = "#{node['wt_common']['install_dir_windows']}\\Webtrends.Portfolio.Manager"
install_logdir = node['wt_common']['install_log_dir_windows']
log_dir = "#{node['wt_common']['install_dir_windows']}\\logs"
dotnet_tempfolder = "%WINDIR%\\Microsoft.Net\\Framework64\\v4.0.30319\\Temporary ASP.NET Files"
app_pool = node['wt_portfolio_manager']['app_pool']
user_data = data_bag_item('authorization', node.chef_environment)
auth_cmd = "/section:applicationPools /[name='#{app_pool}'].processModel.identityType:SpecificUser /[name='#{app_pool}'].processModel.userName:#{user_data['wt_common']['ui_user']} /[name='#{app_pool}'].processModel.password:#{user_data['wt_common']['ui_pass']}"
http_port = node['wt_portfolio_manager']['port']

iis_pool app_pool do
  pipeline_mode :Integrated
  runtime_version "4.0"
  action [:add, :config]
end

iis_site 'Default Web Site' do
  action [:stop, :delete]
end

directory install_dir do
  recursive true
  action :create
end

directory log_dir do
  recursive true
  action :create
end

iis_site 'PortfolioManager' do
  protocol :http
  port http_port
  path install_dir
  action [:add,:start]
  application_pool app_pool
  retries 2
end

#configure IIS
appcmds = Array.new

#enable windows authentication, disable anonymous+forms auth
appcmds << "/section:anonymousAuthentication /enabled:false"
appcmds << "/section:windowsAuthentication /enabled:true"
appcmds << "/commit:WEBROOT /section:system.web/authentication /mode:Windows"
appcmds << "/section:system.web/authentication /mode:Windows"
appcmds << "/section:system.applicationHost/sites /\"[name='PortfolioManager'].virtualDirectoryDefaults.userName\":\"#{user_data['wt_common']['ui_user']}\" /\"[name='PortfolioManager'].virtualDirectoryDefaults.password\":\"#{user_data['wt_common']['ui_pass']}\" /commit:apphost"

#configure IIS
appcmds.each do |thiscmd|
  iis_config "Webtrends IIS Configurations" do
    cfg_cmd thiscmd
    action :config
    returns [0, 183]
  end
end

wt_base_firewall 'PortfolioManager' do
  protocol "TCP"
  port http_port
  action [:open_port]
end

wt_base_icacls install_dir do
  action :grant
  user user_data['wt_common']['ui_user']
  perm :modify
end

# Allow anonymous access to scripts, etc
wt_base_icacls install_dir do
  action :grant
  user "IUSR"
  perm :read
end

wt_base_icacls log_dir do
  action :grant
  user user_data['wt_common']['ui_user']
  perm :modify
end

wt_base_icacls dotnet_tempfolder do
  action :grant
  user user_data['wt_common']['ui_user']
  perm :modify
end 


if ENV["deploy_build"] == "true" then
  windows_zipfile install_dir do
    source node['wt_portfolio_manager']['download_url']
    action :unzip
  end

  iis_config auth_cmd do
    action :config
  end

end

template "#{install_dir}\\appSettings.config" do
  source "appSettings.config.erb"
  variables(
    :cam_url => node['wt_cam']['cam_service_url'],
    :cam_url_base => node['wt_portfolio_manager']['cam_service_url_base'],
    :config_url => node['wt_streamingconfigservice']['config_service_url'],
    :aps_url => node['wt_aps']['service_url'],
    :aps_url_base => node['wt_aps']['aps_url_base'],
    :management_console_url => node['wt_management_console']['service_url'],
    :portmgr_group_admin => node['wt_portfolio_manager']['portmgr_group_admin'],
    :portmgr_group_user => node['wt_portfolio_manager']['portmgr_group_user'],
    :portmgr_injected_user => node['wt_portfolio_manager']['portmgr_injected_user'],
    :portmgr_domain => node['domain'].gsub(".", "").upcase,
    :portmgr_fulfillment_dl => node['wt_portfolio_manager']['portmgr_fulfillment_dl'],
    :portmgr_email_from => node['wt_portfolio_manager']['portmgr_email_from'],
    :streams_ui_url => node['wt_streaming_viz']['streams_ui_url'],
    :auth_url => node['wt_sauth']['auth_service_url'],
    :portmgr_support_dl => node['wt_portfolio_manager']['portmgr_support_dl'],
    :actioncenter_availablecategories => node['wt_portfolio_manager']['actioncenter_availablecategories'],
    :actioncenter_defaultedcategories => node['wt_portfolio_manager']['actioncenter_defaultedcategories']
  )
end

template "#{install_dir}\\web.config" do
  source "web.config.erb"
  variables(
    :elmah_remote_access => node['wt_portfolio_manager']['elmah_remote_access'],
    :custom_errors => node['wt_portfolio_manager']['custom_errors'],
    # proxy
    :proxy_enabled => node['wt_portfolio_manager']['proxy_enabled'],
    :proxy_address => node['wt_common']['http_proxy_url'],
    # smtp relay
    :smtp_host => node['wt_common']['smtp_server'],
    # forms auth
    :machine_validation_key => user_data['wt_iis']['machine_validation_key'],
    :machine_decryption_key => user_data['wt_iis']['machine_decryption_key']
  )
end

template "#{install_dir}\\log4net.config" do
  source "log4net.config.erb"
  variables(
    :log_level => node['wt_portfolio_manager']['log_level'],
    :log_dir => log_dir
  )
end

share_wrs
