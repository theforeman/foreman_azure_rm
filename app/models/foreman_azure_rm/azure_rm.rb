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

    def provider_friendly_name
      'Azure Resource Manager'
    end

    def capabilities
      [:image]
    end

    def regions
      [
          'West Europe',
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

    def new_vm(attr = {})
      AzureRMCompute.new(sdk: sdk)
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
      ActiveSupport::HashWithIndifferentAccess.new
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
      args[:azure_vm][:vm_name] = args[:name].split('.')[0]
      nics = create_nics(args)
      if args[:azure_vm][:password].present? && !args[:azure_vm][:ssh_key_data].present?
        sudoers_cmd = "$echo #{args[:azure_vm][:password]} | sudo -S echo '\"#{args[:azure_vm][:username]}\" ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/waagent"
        if args[:azure_vm][:script_command].present?
          # to run the script_cmd given through form
          # as username
          args[:azure_vm][:script_command] =  sudoers_cmd + " ; su - \"#{args[:azure_vm][:username]}\" -c \"#{args[:azure_vm][:script_command]}\""
        else
          args[:azure_vm][:script_command] =  sudoers_cmd
        end
        disable_password_auth = false
      elsif args[:azure_vm][:ssh_key_data].present? && !args[:azure_vm][:password].present?
        disable_password_auth = true
      else
        disable_password_auth = false
      end
      vm             = create_managed_virtual_machine(
        name:                            args[:azure_vm][:vm_name],
        location:                        args[:azure_vm][:location],
        resource_group:                  args[:azure_vm][:resource_group],
        vm_size:                         args[:azure_vm][:vm_size],
        username:                        args[:azure_vm][:username],
        password:                        args[:azure_vm][:password],
        ssh_key_data:                    args[:azure_vm][:ssh_key_data],
        disable_password_authentication: disable_password_auth,
        network_interface_card_ids:      nics.map(&:id),
        platform:                        args[:azure_vm][:platform],
        vhd_path:                        args[:image_id],
        os_disk_caching:                 args[:azure_vm][:os_disk_caching],
        premium_os_disk:                 args[:azure_vm][:premium_os_disk],
        custom_data:                     args[:user_data],
        script_command:                  args[:azure_vm][:script_command],
        script_uris:                     args[:azure_vm][:script_uris],
      )
      create_vm_extension(args)
      # return the vm object using azure_vm
      return_vm = AzureRMCompute.new(azure_vm: vm, sdk: sdk)
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
