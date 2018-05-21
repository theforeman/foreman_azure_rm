module FogExtensions
  module AzureRM
    module Servers
      extend ActiveSupport::Concern

      module Overrides
        def all(_options = {})
          super()
        end

        def get(uuid)
          raw_vm = service.list_all_vms.find { |vm| vm.name == uuid }
          virtual_machine_fog = Fog::Compute::AzureRM::Server.new(service: service)
          vm_hash = Fog::Compute::AzureRM::Server.parse(raw_vm)
          virtual_machine_fog.merge_attributes(vm_hash)
        end
      end

      included do
        prepend Overrides
      end
    end
  end
end
