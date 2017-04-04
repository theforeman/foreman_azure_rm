module ForemanAzureRM
  class Engine < ::Rails::Engine
    engine_name 'foreman_azure_rm'

    initializer 'foreman_azure_rm.register_plugin', :before => :finisher_hook do
      Foreman::Plugin.register :foreman_azure_rm do
        requires_foreman '>= 1.14'
        compute_resource ForemanAzureRM::AzureRM
      end
    end

    initializer 'foreman_azure_rm.register_gettext', after: :load_config_initializers do
      locale_dir    = File.join(File.expand_path('../../../', __FILE__), 'locale')
      locale_domain = 'foreman_azure_rm'
      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end

    initializer 'foreman_azure_rm.assets.precompile' do |app|
      app.config.assets.precompile += %w(foreman_azure_rm/azure_rm_size_from_location.js
                                         foreman_azure_rm/azure_rm_subnet_from_vnet.js
                                         foreman_azure_rm/azure_rm_location_callbacks.js)
    end

    initializer 'foreman_azure_rm.configure_assets', :group => :assets do
      SETTINGS[:foreman_azure_rm] = { :assets => { :precompile => %w(foreman_azure_rm/azure_rm_size_from_location.js
                                                                   foreman_azure_rm/azure_rm_subnet_from_vnet.js
                                                                   foreman_azure_rm/azure_rm_location_callbacks.js) } }
    end

    config.to_prepare do
      require 'fog/azurerm'

      require 'fog/azurerm/models/compute/server'
      require File.expand_path(
          '../../../app/models/concerns/fog_extensions/azurerm/server',
          __FILE__
      )
      Fog::Compute::AzureRM::Server.send(:include, FogExtensions::AzureRM::Server)

      require 'fog/azurerm/models/compute/servers'
      require File.expand_path(
          '../../../app/models/concerns/fog_extensions/azurerm/servers',
          __FILE__
      )
      Fog::Compute::AzureRM::Servers.send(:include, FogExtensions::AzureRM::Servers)

      require 'fog/azurerm/compute'
      require File.expand_path(
          '../../../app/models/concerns/fog_extensions/azurerm/compute',
          __FILE__
      )
      Fog::Compute::AzureRM::Real.send(:prepend, FogExtensions::AzureRM::Compute)

      ::HostsController.send(:include, ForemanAzureRM::Concerns::HostsControllerExtensions)

      require 'fog/azurerm/models/network/network_interface'
      require 'fog/azurerm/models/network/network_interfaces'
      require File.expand_path(
          '../../../app/models/concerns/fog_extensions/azurerm/network_interfaces',
          __FILE__
      )
      Fog::Network::AzureRM::NetworkInterfaces.send(:include, FogExtensions::AzureRM::NetworkInterfaces)

      require 'fog/azurerm/models/compute/managed_disk'
      require File.expand_path(
          '../../../app/models/concerns/fog_extensions/azurerm/managed_disk',
          __FILE__
      )
      Fog::Compute::AzureRM::ManagedDisk.send(:include, FogExtensions::AzureRM::ManagedDisk)

      require 'fog/azurerm/models/compute/managed_disks'
      require File.expand_path(
          '../../../app/models/concerns/fog_extensions/azurerm/managed_disks',
          __FILE__
      )
      Fog::Compute::AzureRM::ManagedDisks.send(:include, FogExtensions::AzureRM::ManagedDisks)
    end
  end
end