module ForemanAzureRM
  class AzureRMCompute
    attr_accessor :sdk
    attr_accessor :azure_vm
    attr_accessor :resource_group

    delegate :name, to: :azure_vm, allow_nil: true

    def initialize(azure_vm: ComputeModels::VirtualMachine.new,
                   sdk: sdk,
                   resource_group: azure_vm.resource_group)
      @azure_vm = azure_vm
      @sdk = sdk
      @resource_group ||= resource_group
      @azure_vm.hardware_profile ||= ComputeModels::HardwareProfile.new
      @azure_vm.os_profile ||= ComputeModels::OSProfile.new
      @azure_vm.os_profile.linux_configuration ||= ComputeModels::LinuxConfiguration.new
      @azure_vm.os_profile.linux_configuration.ssh ||= ComputeModels::SshConfiguration.new
      @azure_vm.os_profile.linux_configuration.ssh.public_keys ||= [ComputeModels::SshPublicKey.new]
      @azure_vm.storage_profile ||= ComputeModels::StorageProfile.new
      @azure_vm.storage_profile.os_disk ||= ComputeModels::OSDisk.new
    end

    def id
      @azure_vm.id
    end

    def persisted?
      !!identity && !!id
    end

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
    end

    def os_disk_caching
      @azure_vm.storage_profile.os_disk.caching
    end

    def script_command
    end

    def script_uris
    end

    def wait_for(_timeout = 0, _interval = 0, &block)
      instance_eval(&block)
      return true
    end

    def ready?
      vm_status == 'running'
    end

    def state
      vm_status
    end

    def start
      sdk.start_vm(@azure_vm.resource_group, name)
    end

    def stop
      sdk.stop_vm(@azure_vm.resource_group, name)
    end

    def vm_status
      sdk.check_vm_status(@azure_vm.resource_group, name)
    end

    def network_interface_card_ids
      nics = @azure_vm.network_profile.network_interfaces
      nics.map(&:id)
    end

    def provisioning_ip_address
      interfaces.each do |nic|
        nic.ip_configurations.each do |configuration|
          next unless configuration.primary
          if configuration.public_ipaddress.present?
            ip_id     = configuration.public_ipaddress.id
            ip_rg     = ip_id.split('/')[4]
            ip_name   = ip_id.split('/')[-1]
            public_ip = sdk.public_ip(ip_rg, ip_name)
            return public_ip.ip_address
          else
            return configuration.private_ipaddress
          end
        end
      end    
    end

    def interfaces
      interfaces = []
      unless network_interface_card_ids.nil?
        network_interface_card_ids.each do |nic_id|
          nic_rg   = nic_id.split('/')[4]
          nic_name = nic_id.split('/')[-1]
          interfaces << sdk.vm_nic(nic_rg, nic_name)
        end
      end
      interfaces
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

    def image_id
    end
  end
end
