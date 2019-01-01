module ForemanAzureRM
  # rubocop:disable Metrics/ClassLength
  class AzureRM < ComputeResource
    include ForemanAzureRM::FogResources

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

    def available_resource_groups
      rg_client.list_resource_groups
    end

    def storage_accts(location = nil)
      stripped_location = location.gsub(/\s+/, '').downcase

      azure_accounts = storage_client.list_storage_accounts

      unless location.nil?
        azure_accounts = azure_accounts.select do |acct|
          acct.location == stripped_location
        end
      end

      azure_accounts.map(&:name)
    end

    def provided_attributes
      super.merge(:ip => :provisioning_ip_address)
    end

    def host_interfaces_attrs(host)
      physical_interfaces = host.interfaces.select(&:physical?)
      physical_interfaces.each.with_index.reduce({}) do |hash, (nic, index)|
        hash[index.to_s] = nic.compute_attributes.merge(
          ip: nic.ip,
          ip6: nic.ip6
        )
      end
    end

    def available_vnets(_attr = {})
      virtual_networks
    end

    def available_networks(_attr = {})
      subnets
    end

    def virtual_networks(location = nil)
      azure_networks = azure_network_service.virtual_networks
      return azure_networks if location.nil?

      stripped_location = location.gsub(/\s+/, '').downcase
      azure_networks.select { |vnet| vnet.location == stripped_location }
    end

    def subnets(location = nil)
      vnets = virtual_networks(location)
      vnets.flat_map do |vnet|
        azure_network_service.subnets(
          resource_group: vnet.resource_group,
          virtual_network_name: vnet.name
        )
      end
    end
    alias_method :available_subnets, :subnets
    alias_method :networks, :subnets

    def test_connection(options = {})
      Rails.logger.debug('Testing connection, got resource groups:')
      rg_client.resource_groups.each do |rg|
        Rails.logger.debug(rg.name)
      end
      super(options)
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
      vm = vms.all.find { |azure_vm| azure_vm.name == uuid }
      raise ActiveRecord::RecordNotFound unless vm.present?

      vm
    end

    def create_nics(args = {})
      formatted_location = args[:location].gsub(/\s+/, '').downcase
      args[:interfaces_attributes].map do |nic, attrs|
        create_nic(
          nic,
          attrs,
          formatted_location,
          args[:vm_name],
          args[:resource_group]
        )
      end
    end

    def create_nic(nic, attrs, location, vm_name, resource_group)
      attrs[:pubip_alloc] = attrs[:bridge]
      attrs[:privip_alloc] = (attrs[:name] == 'false') ? false : true
      pip = create_pip(attrs[:pubip_alloc], vm_name, nic)
      priv_ip_alloc = translate_private_ip_allocation(attrs[:priv_ip_alloc])
      new_nic = azure_network_service.network_interfaces.create(
        name:                         "#{vm_name}-nic#{nic}",
        resource_group:               resource_group,
        location:                     location,
        subnet_id:                    attrs[:network],
        public_ip_address_id:         pip&.id,
        ip_configuration_name:        'ForemanIPConfiguration',
        private_ip_allocation_method: priv_ip_alloc
      )
      new_nic
    end

    def create_pip(pubip_alloc, vm_name, nic)
      pip_alloc = translate_ip_allocation(pubip_alloc)
      return nil unless pip_alloc.present?

      azure_network_service.public_ips.create(
        name:                        "#{vm_name}-pip#{nic}",
        resource_group:              args[:resource_group],
        location:                    location,
        public_ip_allocation_method: pip_alloc
      )
    end

    # Preferred behavior is to utilize Fog but Fog Azure RM
    # does not currently support creating managed VMs
    def create_vm(args = {})
      args[:vm_name] = args[:name].split('.')[0]
      vm_hash = create_vm_extension(args)
      client.servers.new(vm_hash)
      # fog-azure-rm raises all ARM errors as RuntimeError
    rescue Fog::Errors::Error, RuntimeError => e
      Foreman::Logging.exception('Unhandled Azure RM error', e)
      destroy_vm vm.id if vm
      raise e
    end

    def create_managed_virtual_machine(args)
      nics = create_nics(args)
      disable_password_auth, ssh_key_path = ssh_details(
        args[:ssh_key_data],
        args[:username]
      )
      client.create_managed_virtual_machine(
        extract_create_vm_params(args).merge(
          ssh_key_path:                    ssh_key_path,
          disable_password_authentication: disable_password_auth,
          network_interface_card_ids:      nics.map(&:id)
        )
      )
    end

    def ssh_details(ssh_key_data, username)
      if ssh_key_data.present?
        disable_password_auth = true
        ssh_key_path          = "/home/#{username}/.ssh/authorized_keys"
      else
        disable_password_auth = false
        ssh_key_path          = nil
      end
      [disable_password_auth, ssh_key_path]
    end

    def extract_create_vm_params(args)
      {
        name:                            args[:vm_name],
        location:                        args[:location],
        resource_group:                  args[:resource_group],
        vm_size:                         args[:vm_size],
        username:                        args[:username],
        password:                        args[:password],
        ssh_key_data:                    args[:ssh_key_data],
        platform:                        args[:platform],
        vhd_path:                        args[:image_id],
        os_disk_caching:                 args[:os_disk_caching],
        data_disks:                      args[:volumes_attributes],
        os_disk_size:                    args[:os_disk_size],
        premium_os_disk:                 args[:premium_os_disk]
      }
    end

    def extract_vm_hash(args)
      {
        password: args[:password],
        platform: args[:platform],
        puppet_master: args[:puppet_master],
        script_command: args[:script_command],
        script_uris: args[:script_uris]
      }
    end

    def create_vm_extension(args)
      vm = create_managed_virtual_machine(args)
      vm_hash = Fog::Compute::AzureRM::Server.parse(vm)
      vm_hash.merge(
        extract_vm_hash(args)
      )
      client.create_vm_extension(vm_hash)
      vm_hash
    end

    def destroy_vm(uuid)
      vm           = find_vm_by_uuid(uuid)
      raw_model    = client.get_virtual_machine(vm.resource_group, vm.name)
      # In ARM things must be deleted in order
      vm.destroy
      destroy_nics(nic_ids)
      destroy_managed_disk(vm.resource_group, raw_model)
      destroy_data_disks(raw_model)
    rescue ActiveRecord::RecordNotFound
      # If the VM does not exist, we don't really care.
      true
    end

    private

    def destroy_nics(virtual_machine)
      nic_ids = virtual_machine.network_interface_card_ids
      nic_ids.each do |id|
        nic   = azure_nic(id)
        ip_id = nic.public_ip_address_id
        nic.destroy
        if ip_id.present?
          azure_network_service.public_ips.get(ip_id.split('/')[4],
                                               ip_id.split('/')[-1]).destroy
        end
      end
    end

    def destroy_data_disks(raw_model)
      data_disks = raw_model.storage_profile.data_disks
      data_disks.each do |disk|
        client.managed_disks.get(vm.resource_group, disk.name).destroy
      end
    end

    def destroy_managed_disk(resource_group, raw_model)
      os_disk_name = raw_model.storage_profile.os_disk.name
      client.managed_disks.get(resource_group, os_disk_name).destroy
    end

    def translate_ip_allocation(allocation_attribute)
      case allocation_attribute
      when 'Static'
        Fog::ARM::Network::Models::IPAllocationMethod::Static
      when 'Dynamic'
        Fog::ARM::Network::Models::IPAllocationMethod::Dynamic
      when 'None'
        nil
      else
        raise "Unknown ip allocation method, should be one of: " +
              "[Static, Dynamic, None]"
      end
    end

    def translate_private_ip_allocation(allocation_attribute)
      if allocation_attribute
        Fog::ARM::Network::Models::IPAllocationMethod::Static
      else
        Fog::ARM::Network::Models::IPAllocationMethod::Dynamic
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
