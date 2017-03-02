module FogExtensions
  module AzureRM
    module Server
      extend ActiveSupport::Concern

      def ready?
        vm_status == 'running'
      end

      def state
        vm_status
      end

      def stop
        power_off
        deallocate
      end
    end
  end
end