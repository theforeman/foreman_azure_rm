module ForemanAzureRM
  class AzureRMCompute
    attr_accessor :sdk
    attr_accessor :azure_vm
    attr_accessor :resource_group
    attr_accessor :nics
    attr_accessor :image_id

    delegate :name, to: :azure_vm, allow_nil: true

    def initialize(azure_vm: ComputeModels::VirtualMachine.new,
                   sdk: sdk,
                   resource_group: azure_vm.resource_group,
                   nics: [])

      @azure_vm = azure_vm
      @sdk = sdk
      @resource_group ||= resource_group
      @nics ||= nics
      @azure_vm.hardware_profile ||= ComputeModels::HardwareProfile.new
      @azure_vm.os_profile ||= ComputeModels::OSProfile.new
      @azure_vm.os_profile.linux_configuration ||= ComputeModels::LinuxConfiguration.new
      @azure_vm.os_profile.linux_configuration.ssh ||= ComputeModels::SshConfiguration.new
      @azure_vm.os_profile.linux_configuration.ssh.public_keys ||= [ComputeModels::SshPublicKey.new]
      @azure_vm.storage_profile ||= ComputeModels::StorageProfile.new
      @azure_vm.storage_profile.os_disk ||= ComputeModels::OSDisk.new
      @azure_vm.storage_profile.os_disk.managed_disk ||= ComputeModels::ManagedDiskParameters.new
    end

    def id
      @azure_vm.id
    end

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

    def identity
      @azure_vm.name
    end

    def identity=(setuuid)
      @azure_vm.name = setuuid
    end

    def vm_description
        _("%{vm_size} VM Size") % {:vm_size => vm_size}
    end

    # Following properties are for AzureRM
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

    def os_disk_caching
      @azure_vm.storage_profile.os_disk.caching
    end

    def script_command
    end

    def script_uris
    end
  end
end
