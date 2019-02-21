module FogExtensions
  module AzureRM
    module Server
      extend ActiveSupport::Concern

      attr_accessor :os_disk_size
      attr_accessor :premium_os_disk
      attr_accessor :data_disk_caching
      attr_accessor :os_disk_caching
      attr_accessor :image_id
      attr_accessor :puppet_master
      attr_accessor :script_command
      attr_accessor :script_uris

      def ready?
        vm_status == 'running'
      end

      def state
        vm_status
      end

      def self.prepended base
        base.instance_eval do
          def parse(vm)
            hash                   = {}
            hash['id']             = vm.id
            hash['name']           = vm.name
            hash['location']       = vm.location
            hash['resource_group'] = get_resource_group_from_id(vm.id)
            hash['vm_size']        = vm.hardware_profile.vm_size unless vm.hardware_profile.vm_size.nil?
            unless vm.storage_profile.nil?
              hash['os_disk_name']    = vm.storage_profile.os_disk.name
              hash['os_disk_caching'] = vm.storage_profile.os_disk.caching
              unless vm.storage_profile.os_disk.vhd.nil?
                hash['os_disk_vhd_uri']      = vm.storage_profile.os_disk.vhd.uri
                hash['storage_account_name'] = hash['os_disk_vhd_uri'].split('/')[2].split('.')[0]
              end
              unless vm.storage_profile.image_reference.nil?
                unless vm.storage_profile.image_reference.publisher.nil?
                  hash['publisher'] = vm.storage_profile.image_reference.publisher
                  hash['offer']     = vm.storage_profile.image_reference.offer
                  hash['sku']       = vm.storage_profile.image_reference.sku
                  hash['version']   = vm.storage_profile.image_reference.version
                end
              end
            end

            hash['disable_password_authentication'] = false

            unless vm.os_profile.nil?
              hash['username']    = vm.os_profile.admin_username
              hash['custom_data'] = vm.os_profile.custom_data
              hash['disable_password_authentication'] = vm.os_profile.linux_configuration.disable_password_authentication unless vm.os_profile.linux_configuration.nil?
              if vm.os_profile.windows_configuration
                hash['provision_vm_agent']       = vm.os_profile.windows_configuration.provision_vmagent
                hash['enable_automatic_updates'] = vm.os_profile.windows_configuration.enable_automatic_updates
              end
            end

            hash['data_disks'] = []
            unless vm.storage_profile.data_disks.nil?
              vm.storage_profile.data_disks.each do |disk|
                data_disk = Fog::Compute::AzureRM::DataDisk.new
                hash['data_disks'] << data_disk.merge_attributes(Fog::Compute::AzureRM::DataDisk.parse(disk))
              end
            end

            hash['network_interface_card_ids'] = vm.network_profile.network_interfaces.map(&:id)
            hash['availability_set_id']        = vm.availability_set.id unless vm.availability_set.nil?

            hash
          end
        end
      end

      def interfaces_attributes=(attrs)
        ;
      end

      def provisioning_ip_address
        interfaces.each do |nic|
          nic.ip_configurations.each do |configuration|
            next unless configuration.primary
            if configuration.public_ipaddress.present?
              ip_id     = configuration.public_ipaddress.id
              ip_rg     = ip_id.split('/')[4]
              ip_name   = ip_id.split('/')[-1]
              public_ip = service.get_public_ip(ip_rg, ip_name)
              return public_ip.ip_address
            else
              return configuration.private_ipaddress
            end
          end
        end
      end

      def interfaces
        interfaces = []
        unless attributes[:network_interface_card_ids].nil?
          attributes[:network_interface_card_ids].each do |nic_id|
            nic_rg   = nic_id.split('/')[4]
            nic_name = nic_id.split('/')[-1]
            interfaces << service.get_vm_nic(nic_rg, nic_name)
          end
        end
        interfaces
      end

      def volumes_attributes=(attrs)
        ;
      end

      def volumes
        volumes = []
        unless attributes[:data_disks].nil?
          attributes[:data_disks].each do |disk|
            volumes << disk
          end
        end
        volumes
      end

      def stop
        power_off
        deallocate
      end

    end
  end
end
