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
      rgs = rg_client.list_resource_groups
      rg_names = []
      rgs.each do |rg|
        rg_names << rg.name
      end
      rg_names
    end

    def storage_accts(location = nil)
      stripped_location = location.gsub(/\s+/, '').downcase
      acct_names = []
      if location.nil?
        storage_client.list_storage_accounts.each do |acct|
          acct_names << acct.name
        end
      else
        (storage_client.list_storage_accounts.select { |acct| acct.location == stripped_location}).each do |acct|
          acct_names << acct.name
        end
      end
      acct_names
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
        azure_network_service.virtual_networks.select { |vnet| vnet.location == stripped_location}
      end
    end

    def subnets(vnet)
      split_vnet = vnet.split('/')
      vnet_rg = split_vnet[4]
      vnet_name = split_vnet[-1]
      azure_network_service.subnets(resource_group: vnet_rg, virtual_network_name: vnet_name)
    end

    def test_connection(options = {})
      rg_client.resource_groups.each do |rg|
        puts "#{rg.name}"
      end
      super(options)
    end

    def networks
      subnets  = []
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
      puts 'Listing all VMs'
      container = VMContainer.new
      rg_client.resource_groups.each do |rg|
        puts "#{rg.name}"
        client.servers(resource_group: rg.name).each do |vm|
          puts "#{vm.name}"
          container.virtualmachines << vm
        end
      end
      container
    end

    def vm_sizes(location)
      client.list_available_sizes(location)
    end

    def find_vm_by_uuid(uuid)
      # TODO Find a better way to handle this than loading and sorting through all VMs, which also requires that names be globally unique, instead of unique within a resource group
      vms.all.find { |vm| vm.name == uuid }
    end

    def create_nics(args = {})
      nic_ids = []
      formatted_location = args[:location].gsub(/\s+/,'').downcase
      args[:interfaces_attributes].each do |nic, attrs|
        attrs[:pubip_alloc] = (attrs[:bridge] == 'false') ? false : true
        attrs[:privip_alloc] = (attrs[:name] == 'false') ? false : true
        pip_alloc =  (attrs[:pubip_alloc]) ?
                        Fog::ARM::Network::Models::IPAllocationMethod::Static :
                        Fog::ARM::Network::Models::IPAllocationMethod::Dynamic
        priv_ip_alloc = (attrs[:priv_ip_alloc]) ?
            Fog::ARM::Network::Models::IPAllocationMethod::Static :
            Fog::ARM::Network::Models::IPAllocationMethod::Dynamic
        pip = azure_network_service.public_ips.create(
                                             name: "#{args[:vm_name]}-pip#{nic}",
                                             resource_group: args[:resource_group],
                                             location: formatted_location,
                                             public_ip_allocation_method: pip_alloc
        )
        new_nic = azure_network_service.network_interfaces.create(
                                                       name: "#{args[:vm_name]}-nic#{nic}",
                                                       resource_group: args[:resource_group],
                                                       location: formatted_location,
                                                       subnet_id: attrs[:network],
                                                       public_ip_address_id: pip.id,
                                                       ip_configuration_name: 'ForemanIPConfiguration',
                                                       private_ip_allocation_method: priv_ip_alloc
        )
        nic_ids << new_nic.id
      end
      nic_ids
    end

    def create_vm(args = {})
      args[:vm_name] = args[:name].split('.')[0]
      puts "\n\nARGS: #{args}\n\n"
      nic_ids = create_nics(args)
      vm = client.create_managed_virtual_machine(
                        name: args[:vm_name],
                        location: args[:location],
                        resource_group: args[:resource_group],
                        vm_size: args[:vm_size],
                        storage_account_name: args[:storage_account_name],
                        username: args[:username],
                        password: args[:password],
                        ssh_key_data: args[:ssh_key_data],
                        ssh_key_path: "/home/#{args[:username]}/.ssh/authorized_keys",
                        disable_password_authentication: false,
                        network_interface_card_ids: nic_ids,
                        platform: args[:platform],
                        vhd_path: args[:vhd_path],
                        os_disk_caching: Fog::ARM::Compute::Models::CachingTypes::ReadWrite,
                        data_disks: args[:volumes_attributes],
                        premium_os_disk: args[:premium_os_disk]
      )
      Fog::Compute::AzureRM::Server.new(Fog::Compute::AzureRM::Server.parse(vm))
    end

    protected

    def client
      @client ||= Fog::Compute.new(
                                  :provider => 'AzureRM',
                                  :tenant_id => tenant,
                                  :client_id => app_ident,
                                  :client_secret => secret_key,
                                  :subscription_id => sub_id,
                                  :environment => 'AzureCloud'
      )
    end
    def rg_client
      # noinspection RubyArgCount
      @rg_client ||= Fog::Resources::AzureRM.new(
                                                tenant_id: tenant,
                                                client_id: app_ident,
                                                client_secret: secret_key,
                                                subscription_id: sub_id,
                                                :environment => 'AzureCloud'
      )
    end
    def storage_client
      @storage_client ||= Fog::Storage.new(
                                          :provider => 'AzureRM',
                                          :tenant_id => tenant,
                                          :client_id => app_ident,
                                          :client_secret => secret_key,
                                          :subscription_id => sub_id,
                                          :environment => 'AzureCloud'
      )
    end
    def azure_network_service
      # noinspection RubyArgCount
      @azure_network_service ||= Fog::Network::AzureRM.new(
                                                   :tenant_id => tenant,
                                                   :client_id => app_ident,
                                                   :client_secret => secret_key,
                                                   :subscription_id => sub_id,
                                                   :environment => 'AzureCloud'
      )
    end
  end
end