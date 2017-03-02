module FogExtensions
  module AzureRM
    module Servers
      extend ActiveSupport::Concern

      included do
        alias_method_chain :all, :patched_arguments
      end

      def all_with_patched_arguments(_options = {})
        all_without_patched_arguments
      end
    end
  end
end