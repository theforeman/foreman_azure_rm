module ForemanAzureRm
  class AzureRmCompute
    attr_accessor :sdk
    attr_accessor :azure_vm
    attr_accessor :resource_group
    attr_accessor :nics
    attr_accessor :script_command, :script_uris
    attr_accessor :nvidia_gpu_extension
    attr_accessor :volumes
    attr_accessor :tags

    delegate :name, to: :azure_vm, allow_nil: true

    def initialize(azure_vm: OpenStruct.new,
                   sdk: nil,
                   resource_group: azure_vm.resource_group,
                   nics: [],
                   volumes: [],
                   script_command: nil,
                   script_uris: nil,
                   nvidia_gpu_extension: false,
                   tags: [])
      @azure_vm = azure_vm
      @sdk = sdk
      @resource_group ||= resource_group
      @nics ||= nics
      @volumes ||= volumes
      @script_command ||= script_command
      @script_uris ||= script_uris
      @nvidia_gpu_extension ||= nvidia_gpu_extension
      @tags ||= tags
      @azure_vm.hardware_profile ||= OpenStruct.new
      @azure_vm.os_profile ||= OpenStruct.new
      @azure_vm.os_profile.linux_configuration ||= OpenStruct.new
      @azure_vm.os_profile.linux_configuration.ssh ||= OpenStruct.new
      @azure_vm.os_profile.linux_configuration.ssh.public_keys ||= [OpenStruct.new]
      @azure_vm.storage_profile ||= OpenStruct.new
      @azure_vm.storage_profile.os_disk ||= OpenStruct.new
      @azure_vm.storage_profile.os_disk.managed_disk ||= OpenStruct.new
    end

    delegate :id, to: :@azure_vm

    def persisted?
      !!identity && !!id
    end

    def wait_for(_timeout = 0, _interval = 0, &block)
      instance_eval(&block)
      return true
    end

    def ready?
      vm_status == 'running'
    end

    def reload
    end

    def state
      vm_status
    end

    def start
      sdk.start_vm(@azure_vm.resource_group, name)
      true
    end

    def stop
      sdk.stop_vm(@azure_vm.resource_group, name)
      true
    end

    def to_s
      name
    end

    def vm_status
      sdk.check_vm_status(@azure_vm.resource_group, name)
    end

    def network_interface_card_ids
      return nil unless @azure_vm.network_profile
      nics = @azure_vm.network_profile.network_interfaces
      nics.map(&:id)
    end

    def provisioning_ip_address
      public_ip_address || private_ip_address
    end

    def public_ip_address
      interfaces.each do |nic|
        nic.ip_configurations.each do |configuration|
          next unless configuration.primary
          return nil if configuration.public_ipaddress.blank?
          ip_id     = configuration.public_ipaddress.id
          ip_rg     = ip_id.split('/')[4]
          ip_name   = ip_id.split('/')[-1]
          public_ip = sdk.public_ip(ip_rg, ip_name)
          return public_ip.ip_address
        end
      end
    end

    def private_ip_address
      interfaces.each do |nic|
        nic.ip_configurations.each do |configuration|
          next unless configuration.primary
          if configuration.private_ipaddress.present?
            return private_ip_address = configuration.private_ipaddress
          end
        end
      end
    end

    def interfaces
      nics
    end

    def interfaces_attributes=(attrs)
    end

    def ip_addresses
      []
    end

    def data_disks
      @data_disks ||= @azure_vm.storage_profile.data_disks || []
    end

    def volumes
      return @volumes if data_disks.empty?
      volumes = data_disks.map do |disk|
        OpenStruct.new(:disk => disk, :persisted? => true)
      end
    end

    def volumes_attributes=(attrs)
    end

    def identity
      @azure_vm.name
    end

    def identity=(setuuid)
      @azure_vm.name = setuuid
    end

    def vm_description
        _("%{vm_size} VM Size") % {:vm_size => vm_size}
    end

    # Following properties are for AzureRm
    # These are not part of Foreman's interface

    def vm_size
      @azure_vm.hardware_profile.vm_size
    end

    def platform
      @azure_vm.storage_profile.os_disk.os_type
    end

    def username
      @azure_vm.os_profile.admin_username
    end

    def password
      @azure_vm.os_profile.admin_password
    end

    def ssh_key_data
      # since you can only give one additional
      # sshkey through foreman's UI
      sshkey = @azure_vm.os_profile.linux_configuration.ssh.public_keys[1]
      return unless sshkey.present?
      sshkey.key_data
    end

    def premium_os_disk
      @azure_vm.storage_profile.os_disk.managed_disk.storage_account_type
    end

    def os_disk_size_gb
      @azure_vm.storage_profile.os_disk.disk_size_gb
    end

    def os_disk_caching
      @azure_vm.storage_profile.os_disk.caching
    end

    def image_uuid
      image = @azure_vm.storage_profile.image_reference
      return nil unless image
      if image.id.nil?
        return "marketplace://#{image.publisher}:#{image.offer}:#{image.sku}:#{image.version}"
      else
        parts = image.id.split('/')
        image_rg = parts[4]
        image_name = parts[-1]
        if image.id.include?('/galleries/')
          gallery_name = parts[8]
          return "gallery://#{image_rg}/#{gallery_name}/#{image_name}"
        end
        if sdk.list_custom_images.find { |custom_img| custom_img.name == image_name }
          return "custom://#{image_name}"
        end
      end
    end

    alias_method :image_id, :image_uuid

    def vm_extension
      return nil unless @azure_vm.resources
      @vm_extension ||= begin
        @azure_vm.resources.each do |ext|
          ext_name = ext.id.split('/')[-1]
          next unless ext_name == 'ForemanCustomScript'
          return sdk.get_vm_extension(@azure_vm.resource_group, name, ext_name)
        end
        nil
      end
    end

    def vm_nvidia_gpu_extension
      return nil unless @azure_vm.resources
      @vm_nvidia_gpu_extension ||= begin
        @azure_vm.resources.each do |ext|
          ext_name = ext.id.split('/')[-1]
          next unless ['NvidiaGpuDriverLinux', 'NvidiaGpuDriverWindows'].include? ext_name
          return sdk.get_vm_extension(@azure_vm.resource_group, name, ext_name)
        end
        nil
      end
    end

    def script_command
      if vm_extension.present?
        cmd = vm_extension.settings&.command_to_execute
        return @script_command if cmd.blank? || cmd.ends_with?("waagent")
        if ssh_key_data.nil? && platform == 'Linux'
          c_index = cmd.index("-c")
          return cmd unless c_index
          cmd[(c_index + 4)..-2]
        else
          cmd
        end
      else
        @script_command
      end
    end

    def script_uris
      if vm_extension.present?
        uris = vm_extension.settings&.file_uris
        uris.presence || @script_uris
      else
        @script_uris
      end
    end

    def nvidia_gpu_extension
      vm_nvidia_gpu_extension.present? || @nvidia_gpu_extension
    end

  end
end
