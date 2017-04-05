module FogExtensions
  module AzureRM
    module DataDisk
      extend ActiveSupport::Concern

      def self.prepended base
        base.instance_eval do
          def parse(disk)
            hash = {}
            hash['name'] = disk.name
            hash['disk_size_gb'] = disk.disk_size_gb
            hash['lun'] = disk.lun
            unless disk.vhd.nil?
              hash['vhd_uri'] = disk.vhd.uri
            end
            hash['caching'] = disk.caching unless disk.caching.nil?
            hash['create_option'] = disk.create_option
            hash
          end
        end
      end
    end
  end
end