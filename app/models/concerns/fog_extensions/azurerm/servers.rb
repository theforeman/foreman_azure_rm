module FogExtensions
  module AzureRM
    module Servers
      extend ActiveSupport::Concern

      included do
        alias_method_chain :all, :patched_arguments
        alias_method_chain :get, :patched_arguments
      end

      def all_with_patched_arguments(_options = {})
        all_without_patched_arguments
      end

      def get_with_patched_arguments(uuid)
        raw_vm = service.list_all_vms.find { |vm| vm.name == uuid }
        virtual_machine_fog = Fog::Compute::AzureRM::Server.new(service: service)
        vm_hash = Fog::Compute::AzureRM::Server.parse(raw_vm)
        virtual_machine_fog.merge_attributes(vm_hash)
      end
    end
  end
end