module FogExtensions
  module AzureRM
    module ManagedDisk
      extend ActiveSupport::Concern

      attr_accessor :data_disk_caching

    end
  end
end