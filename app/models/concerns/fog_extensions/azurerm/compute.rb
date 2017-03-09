module FogExtensions
  module AzureRM
    module Compute
      extend ActiveSupport::Concern

      def list_available_sizes(location)
        sizes = []
        @compute_mgmt_client.virtual_machine_sizes.list(location).value().each do |vmsize|
          sizes << vmsize.name
        end
        sizes
      end
    end
  end
end