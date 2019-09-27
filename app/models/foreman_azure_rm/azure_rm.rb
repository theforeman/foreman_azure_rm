# This Model contains code modified as per azure-sdk
# and removed dependencies from fog-azure-rm.
# 
require 'base64'

module ForemanAzureRM
  class AzureRM < ComputeResource

    include VMExtensions::ManagedVM
    alias_attribute :sub_id, :user
    alias_attribute :secret_key, :password
    alias_attribute :app_ident, :url
    alias_attribute :tenant, :uuid

    validates :user, :presence => true
    validates :password, :presence => true
    validates :url, :presence => true
    validates :uuid, :presence => true

    has_one :key_pair, :foreign_key => :compute_resource_id, :dependent => :destroy

    before_create :test_connection, :setup_key_pair

    class VMContainer
      attr_accessor :virtualmachines

      def initialize
        @virtualmachines = []
      end

      def all(_options = {})
        @virtualmachines
      end
    end

    def sdk
      @sdk ||= ForemanAzureRM::AzureSDKAdapter.new(tenant, app_ident, secret_key, sub_id)
    end
    
    def to_label
      "#{name} (#{provider_friendly_name})"
    end

    def self.model_name
      ComputeResource.model_name
    end

    def self.provider_friendly_name
      'Azure Resource Manager'
    end

    def capabilities
      [:image]
    end

    def regions
      [
          ['West Europe', 'westeurope'],
          ['Central US', 'centralus'],
          ['South Central US', 'southcentralus'],
          ['North Central US', 'northcentralus'],
          ['West Central US', 'westcentralus'],
          ['East US', 'eastus'],
          ['East US 2', 'eastus2'],
          ['West US', 'westus'],
          ['West US 2', 'westus2']
      ]
    end

    def storage_accts(region = nil)
      stripped_region = region.gsub(/\s+/, '').downcase
      acct_names        = []
      if region.nil?
        sdk.get_storage_accts.each do |acct|
          acct_names << acct.name
        end
      else
        (sdk.get_storage_accts.select { |acct| acct.region == stripped_region }).each do |acct|
          acct_names << acct.name
        end
      end
      acct_names
    end

    def resource_groups
      sdk.rgs
    end

    def test_connection(options = {})
      sdk.rgs.each do |rg|
        puts "#{rg}"
      end
      super(options)
    end

    def new_vm(args = {})
      if args.empty? || args[:image_id].nil?
        AzureRMCompute.new(sdk: sdk)
      else
        opts = vm_instance_defaults.merge(args.to_h).deep_symbolize_keys
        # convert rails nested_attributes into a plain hash
        [:interfaces].each do |collection|
          nested_args = opts.delete("#{collection}_attributes".to_sym)
          opts[collection] = nested_attributes_for(collection, nested_args) if nested_args
        end
        opts.reject! { |k, v| v.nil? }

        stripped_location = opts[:azure_vm][:location].gsub(/\s+/, '').downcase

        raw_vm = initialize_vm(location:        stripped_location,
                               resource_group:  opts[:resource_group],
                               vm_size:         opts[:vm_size],
                               username:        opts[:username],
                               password:        opts[:password],
                               platform:        opts[:platform],
                               ssh_key_data:    opts[:ssh_key_data],
                               os_disk_caching: opts[:os_disk_caching],
                               vhd_path:        opts[:image_id],
                               premium_os_disk: opts[:premium_os_disk],
                              )
        vm = AzureRMCompute.new(azure_vm: raw_vm ,sdk: sdk, resource_group: opts[:resource_group])
      end
    end

    def provided_attributes
      super.merge({ :ip => :provisioning_ip_address })
    end

    def host_interfaces_attrs(host)
      host.interfaces.select(&:physical?).each.with_index.reduce({}) do |hash, (nic, index)|
        hash.merge(index.to_s => nic.compute_attributes.merge(ip: nic.ip, ip6: nic.ip6))
      end
    end

    def available_vnets(attr = {})
      virtual_networks
    end

    def available_networks(attr = {})
      subnets
    end

    def available_subnets
      subnets
    end

    def virtual_networks(region = nil)
      if region.nil?
        sdk.vnets
      else
        stripped_region = region.gsub(/\s+/, '').downcase
        sdk.vnets.select { |vnet| vnet.location == stripped_region }
      end
    end

    def subnets(region = nil)
      stripped_region = region.gsub(/\s+/, '').downcase
      vnets   = virtual_networks(stripped_region)
      subnets = []
      vnets.each do |vnet|
        subnets.concat(sdk.subnets(vnet.resource_group, vnet.name))
      end
      subnets
    end

    def new_interface(attr = {})
      # WIP
      # calls nic_cards method in adapter
      # causes compute profiles issue
      # NetworkModels::NetworkInterface.new
    end

    def vm_sizes(region)
      sdk.list_vm_sizes(region)
    end

    def associated_host(vm)
      associate_by("ip", [vm.public_ip_address, vm.private_ip_address])
    end

    def vm_instance_defaults
      super.merge(
        interfaces: new_interface
      )
    end

    def vms
      container = VMContainer.new
      # Load all vms
      resource_groups.each do |rg|
        sdk.list_vms(rg).each do |vm|
          container.virtualmachines << AzureRMCompute.new(azure_vm: vm, sdk:sdk)
        end
      end
      container
    end

    def setup_key_pair
      require 'sshkey'
      name = "foreman-#{id}#{Foreman.uuid}"
      key  = ::SSHKey.generate
      build_key_pair :name => name, :secret => key.private_key, :public => key.ssh_public_key
    end

    def find_vm_by_uuid(uuid)
      vm = vms.all.find { |vm| vm.name == uuid }
      raise ActiveRecord::RecordNotFound unless vm.present?
      vm
    end

    # user data support
    def user_data_supported?
      true
    end

    def create_vm(args = {})
      args[:vm_name] = args[:name].split('.')[0]
      nics = create_nics(args)
      if args[:password].present? && !args[:ssh_key_data].present?
        sudoers_cmd = "$echo #{args[:password]} | sudo -S echo '\"#{args[:username]}\" ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/waagent"
        if args[:script_command].present?
          # to run the script_cmd given through form
          # as username
          args[:script_command] =  sudoers_cmd + " ; su - \"#{args[:username]}\" -c \"#{args[:script_command]}\""
        else
          args[:script_command] =  sudoers_cmd
        end
        disable_password_auth = false
      elsif args[:ssh_key_data].present? && !args[:password].present?
        disable_password_auth = true
      else
        disable_password_auth = false
      end

      vm             = create_managed_virtual_machine(
        name:                            args[:vm_name],
        location:                        args[:azure_vm][:location],
        resource_group:                  args[:resource_group],
        vm_size:                         args[:vm_size],
        username:                        args[:username],
        password:                        args[:password],
        ssh_key_data:                    args[:ssh_key_data],
        disable_password_authentication: disable_password_auth,
        network_interface_card_ids:      nics.map(&:id),
        platform:                        args[:platform],
        vhd_path:                        args[:image_id],
        os_disk_caching:                 args[:os_disk_caching],
        premium_os_disk:                 args[:premium_os_disk],
        custom_data:                     args[:user_data],
        script_command:                  args[:script_command],
        script_uris:                     args[:script_uris],
      )
      create_vm_extension(args)
      # return the vm object using azure_vm
      return_vm = AzureRMCompute.new(azure_vm: vm, sdk: sdk, resource_group: args[:resource_group])
    rescue RuntimeError => e
      Foreman::Logging.exception('Unhandled Azure RM error', e)
      destroy_vm vm.id if vm
      raise e
    end

    def destroy_vm(uuid)
      #vm.azure_vm because that's the azure object and vm is the wrapper
      vm           = find_vm_by_uuid(uuid)
      vm_name      = vm.name
      rg_name      = vm.azure_vm.resource_group
      os_disk      = vm.azure_vm.storage_profile.os_disk
      data_disks   = vm.azure_vm.storage_profile.data_disks
      nic_ids      = vm.network_interface_card_ids

      sdk.delete_vm(rg_name, vm_name)

      nic_ids.each do |nic_id|
        nic = sdk.vm_nic(rg_name, nic_id.split('/')[-1])
        if nic.present?
          public_ip = nic.ip_configurations.first.public_ipaddress
          sdk.delete_nic(rg_name, nic_id.split('/')[-1])
          if public_ip.present?
            ip_id = public_ip.id
            sdk.delete_pip(rg_name, ip_id.split('/')[-1])
          end
        end
      end
      if os_disk.present?
        sdk.delete_disk(rg_name, os_disk.name)
      end

      true
    rescue ActiveRecord::RecordNotFound
      logger.info "Could not find the selected vm."
      true
    end
  end
end
