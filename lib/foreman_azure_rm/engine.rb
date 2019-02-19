module ForemanAzureRM
  class Engine < ::Rails::Engine
    engine_name 'foreman_azure_rm'

    initializer 'foreman_azure_rm.register_plugin', :before => :finisher_hook do
      Foreman::Plugin.register :foreman_azure_rm do
        requires_foreman '>= 1.17'
        compute_resource ForemanAzureRM::AzureRM
      end
    end

    # rubocop:disable Metrics/LineLength
    initializer 'foreman_azure_rm.register_gettext', after: :load_config_initializers do
      locale_dir    = File.join(File.expand_path('../..', __dir__), 'locale')
      locale_domain = 'foreman_azure_rm'
      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end
    # rubocop:enable Metrics/LineLength

    # rubocop:disable Metrics/BlockLength, Metrics/LineLength
    config.to_prepare do
      require 'fog/azurerm'

      require 'fog/azurerm/models/compute/server'
      require File.expand_path(
        '../../app/models/concerns/fog_extensions/azurerm/server',
        __dir__
      )
      Fog::Compute::AzureRM::Server.send(:prepend, FogExtensions::AzureRM::Server)

      require 'fog/azurerm/models/compute/servers'
      require File.expand_path(
        '../../app/models/concerns/fog_extensions/azurerm/servers',
        __dir__
      )
      Fog::Compute::AzureRM::Servers.send(:include, FogExtensions::AzureRM::Servers)

      require 'fog/azurerm/models/storage/data_disk'
      require File.expand_path(
        '../../app/models/concerns/fog_extensions/azurerm/data_disk',
        __dir__
      )
      Fog::Storage::AzureRM::DataDisk.send(:prepend, FogExtensions::AzureRM::DataDisk)

      require 'fog/azurerm/compute'
      require File.expand_path(
        '../../app/models/concerns/fog_extensions/azurerm/compute',
        __dir__
      )
      Fog::Compute::AzureRM::Real.send(:prepend, FogExtensions::AzureRM::Compute)

      ::HostsController.send(:include, ForemanAzureRM::Concerns::HostsControllerExtensions)

      Api::V2::ComputeResourcesController.send(:include, ForemanAzureRM::Concerns::ComputeResourcesControllerExtensions)

      require 'fog/azurerm/models/network/network_interface'
      require File.expand_path(
        '../../app/models/concerns/fog_extensions/azurerm/network_interface',
        __dir__
      )
      Fog::Network::AzureRM::NetworkInterface.send(:include, FogExtensions::AzureRM::NetworkInterface)

      require 'fog/azurerm/models/network/network_interfaces'
      require File.expand_path(
        '../../app/models/concerns/fog_extensions/azurerm/network_interfaces',
        __dir__
      )
      Fog::Network::AzureRM::NetworkInterfaces.send(:include, FogExtensions::AzureRM::NetworkInterfaces)

      require 'fog/azurerm/models/compute/managed_disk'
      require File.expand_path(
        '../../app/models/concerns/fog_extensions/azurerm/managed_disk',
        __dir__
      )
      Fog::Compute::AzureRM::ManagedDisk.send(:include, FogExtensions::AzureRM::ManagedDisk)

      require 'fog/azurerm/models/compute/managed_disks'
      require File.expand_path(
        '../../app/models/concerns/fog_extensions/azurerm/managed_disks',
        __dir__
      )
      Fog::Compute::AzureRM::ManagedDisks.send(:include, FogExtensions::AzureRM::ManagedDisks)
    end
    # rubocop:enable Metrics/BlockLength, Metrics/LineLength
  end
end
