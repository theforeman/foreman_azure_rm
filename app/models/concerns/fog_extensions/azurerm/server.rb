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

      def interfaces_attributes=(attrs); end

      def provisioning_ip_address
        interfaces.each do |nic|
          nic.ip_configurations.each do |configuration|
            next unless configuration.primary
            if configuration.public_ipaddress.present?
              ip_id = configuration.public_ipaddress.id
              ip_rg = ip_id.split('/')[4]
              ip_name = ip_id.split('/')[-1]
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

      def volumes_attributes=(attrs); end

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