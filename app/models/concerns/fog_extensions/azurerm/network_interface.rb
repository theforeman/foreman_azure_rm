module FogExtensions
  module AzureRM
    module NetworkInterface
      extend ActiveSupport::Concern

      attr_accessor :network
      attr_accessor :bridge

      def new(attr = {})
        if resource_group
          super({:resource_group => resource_group}.merge(attr))
        else
          super
        end
      end

    end
  end
end