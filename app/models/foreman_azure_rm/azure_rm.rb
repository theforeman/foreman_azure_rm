# This Model contains code modified as per azure-sdk
# and removed dependencies from fog-azure-rm.

require 'base64'

module ForemanAzureRm
  class AzureRm < ComputeResource

    include VMExtensions::ManagedVM

    alias_attribute :sub_id, :user
    alias_attribute :secret_key, :password
    alias_attribute :region, :url
    alias_attribute :tenant, :uuid
    alias_attribute :azure_environment, :cloud

    validates :user, :password, :uuid, :app_ident, :presence => true

    has_one :key_pair, :foreign_key => :compute_resource_id, :dependent => :destroy

    before_create :test_connection, :setup_key_pair

    validate :ensure_attributes_and_values

    class VMContainer
      attr_accessor :virtualmachines
      delegate :each, to: :virtualmachines

      def initialize
        @virtualmachines = []
      end

      def all(_options = {})
        @virtualmachines
      end
    end

    def app_ident
      attrs[:app_ident]
    end

    def app_ident=(name)
      attrs[:app_ident] = name
    end

    def cloud
      attrs[:cloud] || 'azure'
    end

    def cloud=(name)
      attrs[:cloud] = name
    end

    def sdk
      @sdk ||= ForemanAzureRm::AzureSdkAdapter.new(tenant, app_ident, secret_key, sub_id, azure_environment,
                                                     proxy_url: connection_options[:proxy],
                                                     ssl_cert_store: connection_options[:ssl_cert_store])
    end

    def to_label
      "#{name} (#{provider_friendly_name})"
    end

    def ensure_attributes_and_values
      validate_region if validate_cloud?
    end

    def validate_region
      return unless regions.present?
      errors.add(:region, _("is not valid, must be lowercase eg. 'eastus'. No special characters allowed.")) unless regions.collect(&:second).include?(region)
    end

    def validate_cloud?
      valid_clouds = ['azure', 'azureusgovernment', 'azurechina', 'azuregermancloud']
      unless valid_clouds.include?(cloud)
      	errors.add(:cloud, _("is not valid. Valid choices are %s.") % valid_clouds.join(", "))
	      return false
      end
      true
    end

    def self.model_name
      ComputeResource.model_name
    end

    def self.provider_friendly_name
      'Microsoft Azure'
    end

    def capabilities
      [:image, :new_volume]
    end

    def regions
      return unless sub_id.present?
      (sdk.list_regions(sub_id).value || []).map { |loc| [loc.display_name, loc.name] }
    end

    def resource_groups
      sdk.rgs
    end

    def test_connection(options = {})
      super
      errors[:user].empty? && errors[:password].empty? && errors[:uuid].empty? && errors[:app_ident].empty? && errors[:cloud].empty? && regions
    rescue StandardError => e
      errors.add(:base, e.message)
    end

    def new_vm(args = {})
      return AzureRmCompute.new(sdk: sdk) if args.empty?
      opts = vm_instance_defaults.merge(args.to_h).deep_symbolize_keys
      # convert rails nested_attributes into a plain hash
      [:interfaces, :volumes].each do |collection|
        nested_args = opts.delete(:"#{collection}_attributes")
        opts[collection] = nested_attributes_for(collection, nested_args) if nested_args
      end
      opts.reject! { |k, v| v.nil? }

      raw_vm = initialize_vm(location:        region,
                             resource_group:  opts[:resource_group],
                             vm_size:         opts[:vm_size],
                             username:        opts[:username],
                             password:        opts[:password],
                             platform:        opts[:platform],
                             ssh_key_data:    opts[:ssh_key_data],
                             os_disk_caching: opts[:os_disk_caching],
                             premium_os_disk: opts[:premium_os_disk],
                             os_disk_size_gb: opts[:os_disk_size_gb],
                             nvidia_gpu_extension: opts[:nvidia_gpu_extension],
                            )
      ifaces = []
      if opts[:interfaces].present?
        opts[:interfaces].each_with_index do |iface_attrs, i|
          ifaces << new_interface(iface_attrs)
        end
      end

      vols = opts.fetch(:volumes, []).map { |vols_attrs| new_volume(vols_attrs) } if opts[:volumes].present?

      AzureRmCompute.new(
        azure_vm: raw_vm,
        sdk: sdk,
        resource_group: opts[:resource_group],
        nics: ifaces,
        volumes: vols,
        script_command: opts[:script_command],
        script_uris: opts[:script_uris],
        nvidia_gpu_extension: ActiveRecord::Type::Boolean.new.deserialize(opts[:nvidia_gpu_extension]),
      )
    end

    def provided_attributes
      super.merge({ :ip => :provisioning_ip_address })
    end

    def image_exists?(image)
      image_type, image_id = image.split('://')
      case image_type
      when 'marketplace'
        begin
          urn = image_id.split(':')
          publisher = urn[0]
          offer     = urn[1]
          sku       = urn[2]
          version   = urn[3]
          if version == "latest"
            all_versions = sdk.list_versions(region, publisher, offer, sku).map(&:name)
            return true if all_versions.any?
          end
          sdk.get_marketplace_image(region, publisher, offer, sku, version).present?
        rescue StandardError => e
          return false
        end
      when 'gallery'
        begin
          resolved_id = sdk.fetch_gallery_image_id(nil, image_id)
          return false unless resolved_id

          id_parts = resolved_id.split('/')
          rg_name = id_parts[4]
          gallery_name = id_parts[8]
          image_name = id_parts[-1]

          image_versions = sdk.list_gallery_image_versions(rg_name, gallery_name, image_name)
          target_regions = image_versions.flat_map do |image_version|
            (image_version.publishing_profile&.target_regions || []).map(&:name)
          end.uniq.map { |tgt_reg| tgt_reg.gsub(/\s+/, '').downcase }

          target_regions.include?(region)
        rescue ArgumentError => e
          raise e
        rescue StandardError => e
          Rails.logger.warn("Gallery check failed: #{e.message}")
          false
        end
      when 'custom'
        custom_image = sdk.list_custom_images.detect { |custom_img| custom_img.name == image_id && custom_img.location == region }
        return custom_image.present?
      else
        false
      end
    end

    def available_vnets(attr = {})
      virtual_networks
    end

    def available_networks(attr = {})
      subnets
    end

    def virtual_networks
      @virtual_networks ||= sdk.vnets.select { |vnet| vnet.location == region }
    end

    def subnets
      vnets   = virtual_networks
      subnets = []
      vnets.each do |vnet|
        subnets.concat(sdk.subnets(vnet.resource_group, vnet.name))
      end
      subnets
    end

    alias_method :available_subnets, :subnets

    def new_interface(attrs = {})
      args = { :network => "", :public_ip => "", :private_ip => false, 'persisted?' => false }.merge(attrs.to_h)
      OpenStruct.new(args)
    end

    def editable_network_interfaces?
      true
    end

    def new_volume(attrs = {})
      args = { :disk_size_gb => 0, :data_disk_caching => "", 'persisted?' => false }.merge(attrs.to_h)
      OpenStruct.new(args)
    end

    def vm_sizes
      sdk.list_vm_sizes(region)
    end

    def associated_host(vm)
      associate_by("ip", [vm.public_ip_address, vm.private_ip_address])
    end

    def vm_instance_defaults
      super.deep_merge(
        interfaces: [new_interface],
        volumes: [new_volume]
      )
    end

    def vm_nics(vm)
      ifaces = []
      vm.network_profile.network_interfaces.each do |nic|
        nic_rg = (split_nic_id = nic.id.split('/'))[4]
        nic_name = split_nic_id[-1]
        ifaces << sdk.vm_nic(nic_rg, nic_name)
      end
      ifaces
    end

    def vm_disks(vm)
      vm.storage_profile.data_disks
    end

    def vms(attrs = {})
      container = VMContainer.new
      # Load all vms of the region
      sdk.list_vms(region).each do |vm|
        container.virtualmachines << AzureRmCompute.new(azure_vm: vm, sdk:sdk, nics: vm_nics(vm))
      end
      container
    end

    def setup_key_pair
      name = "foreman-#{id}#{Foreman.uuid}"
      key_pair = Foreman::Provision::SshKey.generate
      build_key_pair :name => name, :secret => key_pair.private_key, :public => key_pair.public_key
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
      args = args.to_h.deep_symbolize_keys
      args[:vm_name] = args[:name].split('.')[0]
      created = create_nics(region, args)
      nics = created[:nics]
      pips = created[:pips]
      vm = nil
      user_command = args[:script_command]

      if args[:platform] == 'Linux'
        if args[:password].present? && !args[:ssh_key_data].present?
          if args[:script_command].present?
            args[:script_command] = "su - \"#{args[:username]}\" -c \"#{user_command}\""
          end
          disable_password_auth = false
        elsif args[:ssh_key_data].present? && !args[:password].present?
          disable_password_auth = true
        else
          disable_password_auth = false
        end
      end

      vm             = create_managed_virtual_machine(
        name:                            args[:vm_name],
        location:                        region,
        resource_group:                  args[:resource_group],
        vm_size:                         args[:vm_size],
        username:                        args[:username],
        password:                        args[:password],
        ssh_key_data:                    args[:ssh_key_data],
        disable_password_authentication: disable_password_auth,
        network_interface_card_ids:      nics.map(&:id),
        platform:                        args[:platform],
        image_id:                        args[:image_id],
        os_disk_caching:                 args[:os_disk_caching],
        premium_os_disk:                 args[:premium_os_disk],
        os_disk_size_gb:                 args[:os_disk_size_gb],
        data_disks:                      args[:volumes_attributes],
        custom_data:                     args[:user_data],
        script_command:                  args[:script_command],
        script_uris:                     args[:script_uris],
        nvidia_gpu_extension:            args[:nvidia_gpu_extension],
        tags:                            args[:tags],
      )
      logger.debug "Virtual Machine #{args[:vm_name]} Created Successfully."
      # request NVIDIA GPU driver and CUDA stack
      if ActiveRecord::Type::Boolean.new.deserialize(args[:nvidia_gpu_extension])
        create_vm_nvidia_gpu_extension(region, args)
      end
      # as this extension may contains postinstall script, call it after others
      create_vm_extension(region, args)
      # return the vm object using azure_vm
      AzureRmCompute.new(
        azure_vm: vm,
        sdk: sdk,
        resource_group: args[:resource_group],
        nics: vm_nics(vm),
        volumes: vm_disks(vm),
        script_command: user_command,
        script_uris: args[:script_uris],
        nvidia_gpu_extension: ActiveRecord::Type::Boolean.new.deserialize(args[:nvidia_gpu_extension]),
        tags: args[:tags],
      )
    rescue ForemanAzureRm::AzureApiError, RuntimeError => e
      Foreman::Logging.exception('Unhandled AzureRm error', e)
      best_effort("VM cleanup") { destroy_vm(args[:vm_name]) } if args[:vm_name]
      nics&.each { |nic| best_effort("NIC #{nic.name}") { sdk.delete_nic(args[:resource_group], nic.name) } }
      pips&.each { |pip| best_effort("PIP #{pip.name}") { sdk.delete_pip(args[:resource_group], pip.name) } }
      raise e
    end

    def destroy_vm(uuid)
      vm           = find_vm_by_uuid(uuid)
      rg_name      = vm.resource_group
      os_disk      = vm.azure_vm.storage_profile.os_disk
      data_disks   = vm.azure_vm.storage_profile.data_disks
      nic_ids      = vm.network_interface_card_ids

      sdk.delete_vm(rg_name, vm.name)

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
      sdk.delete_disk(rg_name, os_disk.name) if os_disk.present?
      data_disks.each { |data_disk| sdk.delete_disk(rg_name, data_disk.name) } if data_disks.present?
      true
    rescue ActiveRecord::RecordNotFound
      logger.info "Could not find the selected vm."
      true
    end

    private

    def best_effort(description)
      yield
    rescue StandardError => e
      logger.warn("#{description} failed: #{e.message}")
    end
  end
end
