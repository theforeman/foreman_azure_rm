module FogExtensions
  module AzureRM
    module Server
      extend ActiveSupport::Concern

      attr_accessor :premium_os_disk

      def ready?
        vm_status == 'running'
      end

      def state
        vm_status
      end

      def interfaces_attributes=(attrs); end

      def interfaces
        interfaces = []
        unless attributes[:network_interface_cards].nil?
          attributes[:network_interface_card_ids].each do |nic_id|
            nic_rg = nic_id.split('/')[4]
            nic_name = nic_id.split('/')[-1]
            interfaces << @azure_network_service.network_interfaces.get(nic_rg, nic_name)
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