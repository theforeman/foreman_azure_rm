module ForemanAzureRm
  class Engine < ::Rails::Engine
    engine_name 'foreman_azure_rm'

    #autoloading all files inside lib dir
    config.eager_load_paths += Dir["#{config.root}/lib"]
    config.eager_load_paths += Dir["#{config.root}/app/models/concerns/foreman_azure_rm/vm_extensions/"]
    config.eager_load_paths += Dir["#{config.root}/app/helpers/"]

    initializer 'foreman_azure_rm.register_plugin', :before => :finisher_hook do
      Foreman::Plugin.register :foreman_azure_rm do
        requires_foreman '>= 3.7'
        register_gettext
        compute_resource ForemanAzureRm::AzureRm
        parameter_filter ComputeResource, :azure_vm, :tenant, :app_ident, :secret_key, :sub_id, :region, :cloud
      end
    end

    # Add any db migrations
    initializer "foreman_azure_rm.load_app_instance_data" do |app|
      ForemanAzureRm::Engine.paths['db/migrate'].existent.each do |path|
        app.config.paths['db/migrate'] << path
      end
    end

    initializer "foreman_azure_rm.add_rabl_view_path" do
      Rabl.configure do |config|
        config.view_paths << ForemanAzureRm::Engine.root.join('app', 'views')
      end
    end

    config.to_prepare do
      require 'azure_mgmt_resources'
      require 'azure_mgmt_network'
      require 'azure_mgmt_storage'
      require 'azure_mgmt_compute'
      require 'azure_mgmt_subscriptions'

      # Add format validation for azure images
      ::Image.validates :uuid, uniqueness: { scope: :compute_resource_id, case_sensitive: false }, format: { with: /\A((marketplace|custom|gallery):\/\/)[^:]+(:[^:]+:[^:]+:[^:]+)?\z/,
          message: "Incorrect UUID format" }, if: -> (image){ image.compute_resource.is_a? ForemanAzureRm::AzureRm }

      # Use excon as default so that HTTP Proxy settings of foreman works
      Faraday::default_adapter=:excon

      ::HostsController.send(:include, ForemanAzureRm::Concerns::HostsControllerExtensions)

      Api::V2::ComputeResourcesController.send(:include, ForemanAzureRm::Concerns::ComputeResourcesControllerExtensions)
    end

    rake_tasks do
      load "foreman_azure_rm.rake"
    end
  end
end
