module ForemanAzureRM
  class AzureRM < ComputeResource
    alias_attribute :sub_id, :user
    alias_attribute :secret_key, :password
    alias_attribute :app_ident, :url
    alias_attribute :tenant, :uuid

    before_create :test_connection

    class VMContainer
      attr_accessor :virtualmachines

      def initialize
        @virtualmachines = []
      end

      def all(_options = {})
        @virtualmachines
      end
    end

    def to_label
      "#{name} (#{provider_friendly_name})"
    end

    def self.model_name
      ComputeResource.model_name
    end

    def provider_friendly_name
      'Azure Resource Manager'
    end

    def capabilities
      [:image]
    end

    def locations
      [
          'Central US',
          'South Central US',
          'North Central US',
          'West Central US',
          'East US',
          'East US 2',
          'West US',
          'West US 2'
      ]
    end

    def resource_groups
      rgs      = rg_client.list_resource_groups
      rg_names = []
      rgs.each do |rg|
        rg_names << rg.name
      end
      rg_names
    end

    def storage_accts(location = nil)
      stripped_location = location.gsub(/\s+/, '').downcase
      acct_names        = []
      if location.nil?
        storage_client.list_storage_accounts.each do |acct|
          acct_names << acct.name
        end
      else
        (storage_client.list_storage_accounts.select { |acct| acct.location == stripped_location }).each do |acct|
          acct_names << acct.name
        end
      end
      acct_names
    end

    def provided_attributes
      super.merge({ :ip => :provisioning_ip_address })
    end

    def host_interfaces_attrs(host)
      host.interfaces.select(&:physical?).each.with_index.reduce({}) do |hash, (nic, index)|
        hash.merge(index.to_s => nic.compute_attributes.merge(ip: nic.ip, ip6: nic.ip6))
      end
    end

    def virtual_networks(location = nil)
      if location.nil?
        azure_network_service.virtual_networks
      else
        stripped_location = location.gsub(/\s+/, '').downcase
        azure_network_service.virtual_networks.select { |vnet| vnet.location == stripped_location }
      end
    end

    def subnets(location)
      vnets   = virtual_networks(location)
      subnets = []
      vnets.each do |vnet|
        subnets.concat(azure_network_service.subnets(resource_group:       vnet.resource_group,
                                                     virtual_network_name: vnet.name).all)
      end
      subnets
    end

    def test_connection(options = {})
      rg_client.resource_groups.each do |rg|
        puts "#{rg.name}"
      end
      super(options)
    end

    def networks
      subnets = []
      virtual_networks.each do |vnet|
        subnets << subnets(vnet.id)
      end
      subnets
    end

    def new_interface(attr = {})
      azure_network_service.network_interfaces.new(attr)
    end

    def new_volume(attr = {})
      client.managed_disks.new(attr)
    end

    def vms
      container = VMContainer.new
      rg_client.resource_groups.each do |rg|
        client.servers(resource_group: rg.name).each do |vm|
          container.virtualmachines << vm
        end
      end
      container
    end

    def vm_sizes(location)
      client.list_available_sizes(location)
    end

    def find_vm_by_uuid(uuid)
      # TODO: Find a better way to handle this than loading and sorting through
      # all VMs, which also requires that names be globally unique, instead of
      # unique within a resource group
      vm = vms.all.find { |vm| vm.name == uuid }
      raise ActiveRecord::RecordNotFound unless vm.present?
      vm
    end

    def create_nics(args = {})
      nics = []
      formatted_location = args[:location].gsub(/\s+/, '').downcase
      args[:interfaces_attributes].each do |nic, attrs|
        attrs[:pubip_alloc] = attrs[:bridge]
        attrs[:privip_alloc] = (attrs[:name] == 'false') ? false : true
        pip_alloc = case attrs[:pubip_alloc]
                    when 'Static'
                      Fog::ARM::Network::Models::IPAllocationMethod::Static
                    when 'Dynamic'
                      Fog::ARM::Network::Models::IPAllocationMethod::Dynamic
                    when 'None'
                      nil
                    end
        priv_ip_alloc = if attrs[:priv_ip_alloc]
                          Fog::ARM::Network::Models::IPAllocationMethod::Static
                        else
                          Fog::ARM::Network::Models::IPAllocationMethod::Dynamic
                        end
        if pip_alloc.present?
          pip = azure_network_service.public_ips.create(
              name:                        "#{args[:vm_name]}-pip#{nic}",
              resource_group:              args[:resource_group],
              location:                    formatted_location,
              public_ip_allocation_method: pip_alloc
          )
        end
        new_nic = azure_network_service.network_interfaces.create(
            name:                         "#{args[:vm_name]}-nic#{nic}",
            resource_group:               args[:resource_group],
            location:                     formatted_location,
            subnet_id:                    attrs[:network],
            public_ip_address_id:         pip.present? ? pip.id : nil,
            ip_configuration_name:        'ForemanIPConfiguration',
            private_ip_allocation_method: priv_ip_alloc
        )
        nics << new_nic
      end
      nics
    end

    # Preferred behavior is to utilize Fog but Fog Azure RM
    # does not currently support creating managed VMs
    def create_vm(args = {})
      args[:vm_name] = args[:name].split('.')[0]
      nics = create_nics(args)
      if args[:ssh_key_data].present?
        disable_password_auth = true
        ssh_key_path          = "/home/#{args[:username]}/.ssh/authorized_keys"
      else
        disable_password_auth = false
        ssh_key_path          = nil
      end
      vm = client.create_managed_virtual_machine(
          name:                            args[:vm_name],
          location:                        args[:location],
          resource_group:                  args[:resource_group],
          vm_size:                         args[:vm_size],
          username:                        args[:username],
          password:                        args[:password],
          ssh_key_data:                    args[:ssh_key_data],
          ssh_key_path:                    ssh_key_path,
          disable_password_authentication: disable_password_auth,
          network_interface_card_ids:      nics.map(&:id),
          platform:                        args[:platform],
          vhd_path:                        args[:image_id],
          os_disk_caching:                 args[:os_disk_caching],
          data_disks:                      args[:volumes_attributes],
          os_disk_size:                    args[:os_disk_size],
          premium_os_disk:                 args[:premium_os_disk],
      )
      vm_hash                      = Fog::Compute::AzureRM::Server.parse(vm)
      vm_hash[:password]           = args[:password]
      vm_hash[:platform]           = args[:platform]
      vm_hash[:puppet_master]      = args[:puppet_master]
      vm_hash[:script_command]     = args[:script_command]
      vm_hash[:script_uris]        = args[:script_uris]
      client.create_vm_extension(vm_hash)
      client.servers.new vm_hash
    # fog-azure-rm raises all ARM errors as RuntimeError
    rescue Fog::Errors::Error, RuntimeError => e
      Foreman::Logging.exception('Unhandled Azure RM error', e)
      destroy_vm vm.id if vm
      raise e
    end

    def destroy_vm(uuid)
      vm           = find_vm_by_uuid(uuid)
      raw_model    = client.get_virtual_machine(vm.resource_group, vm.name)
      os_disk_name = raw_model.storage_profile.os_disk.name
      data_disks   = raw_model.storage_profile.data_disks
      nic_ids      = vm.network_interface_card_ids
      # In ARM things must be deleted in order
      vm.destroy
      nic_ids.each do |id|
        nic = azure_network_service.network_interfaces.get(id.split('/')[4],
                                                           id.split('/')[-1])
        ip_id = nic.public_ip_address_id
        nic.destroy
        if ip_id.present?
          azure_network_service.public_ips.get(ip_id.split('/')[4],
                                               ip_id.split('/')[-1]).destroy
        end
      end
      client.managed_disks.get(vm.resource_group, os_disk_name).destroy
      data_disks.each do |disk|
        client.managed_disks.get(vm.resource_group, disk.name).destroy
      end

    rescue ActiveRecord::RecordNotFound
      # If the VM does not exist, we don't really care.
      true
    end

    protected

    def client
      @client ||= Fog::Compute.new(
          :provider        => 'AzureRM',
          :tenant_id       => tenant,
          :client_id       => app_ident,
          :client_secret   => secret_key,
          :subscription_id => sub_id,
          :environment     => 'AzureCloud'
      )
    end

    def rg_client
      # noinspection RubyArgCount
      @rg_client ||= Fog::Resources::AzureRM.new(
          tenant_id:       tenant,
          client_id:       app_ident,
          client_secret:   secret_key,
          subscription_id: sub_id,
          :environment     => 'AzureCloud'
      )
    end

    def storage_client
      @storage_client ||= Fog::Storage.new(
          :provider        => 'AzureRM',
          :tenant_id       => tenant,
          :client_id       => app_ident,
          :client_secret   => secret_key,
          :subscription_id => sub_id,
          :environment     => 'AzureCloud'
      )
    end

    def azure_network_service
      # noinspection RubyArgCount
      @azure_network_service ||= Fog::Network::AzureRM.new(
          :tenant_id       => tenant,
          :client_id       => app_ident,
          :client_secret   => secret_key,
          :subscription_id => sub_id,
          :environment     => 'AzureCloud'
      )
    end
  end
end