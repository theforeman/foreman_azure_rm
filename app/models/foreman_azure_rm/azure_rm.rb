module ForemanAzureRM
  class AzureRM < ComputeResource
    alias_attribute :sub_id, :user
    alias_attribute :secret_key, :password
    alias_attribute :app_ident, :url
    alias_attribute :tenant, :uuid

    before_create :test_connection

    class VMContainer
      attr_accessor :virtualmachines
      def initialize
        @virtualmachines = []
      end
      def all(_options = {})
        @virtualmachines
      end
    end

    def to_label
      "#{name} (#{provider_friendly_name})"
    end

    def self.model_name
      ComputeResource.model_name
    end

    def provider_friendly_name
      'Azure Resource Manager'
    end

    def capabilities
      [:image]
    end

    def locations
      []
    end
    def test_connection(options = {})
      puts "#{sub_id}", "#{app_ident}", "#{secret_key}", "#{tenant}"
      rg_client.resource_groups.each do |rg|
        puts "#{rg.name}"
      end
      super(options)
    end

    def vms
      container = VMContainer.new
      rg_client.resource_groups.each do |rg|
        puts "#{rg.name}"
        client.servers(resource_group: rg.name).each do |vm|
          puts "#{vm.name}"
          container.virtualmachines << vm
        end
      end
      container
    end

    def find_vm_by_uuid(uuid)
      # TODO Find a better way to handle this than loading and sorting through all VMs, which also requires that names be globally unique, instead of unique within a resource group
      vms.all.find { |vm| vm.name == uuid }
    end

    protected

    def client
      @client ||= Fog::Compute.new(
                                  :provider => 'AzureRM',
                                  :tenant_id => tenant,
                                  :client_id => app_ident,
                                  :client_secret => secret_key,
                                  :subscription_id => sub_id,
                                  :environment => 'AzureCloud'
      )
    end
    def rg_client
      # noinspection RubyArgCount
      @rg_client ||= Fog::Resources::AzureRM.new(
                                                tenant_id: tenant,
                                                client_id: app_ident,
                                                client_secret: secret_key,
                                                subscription_id: sub_id,
                                                :environment => 'AzureCloud'
      )
    end
  end
end