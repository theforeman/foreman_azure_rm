module FogExtensions
  module AzureRM
    module NetworkInterfaces
      extend ActiveSupport::Concern

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