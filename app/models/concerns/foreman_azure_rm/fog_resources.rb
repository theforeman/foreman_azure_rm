module ForemanAzureRM
  module FogResources
    extend ActiveSupport::Concern

    def client
      @client ||= Fog::Compute.new(
        :provider        => 'AzureRM',
        :tenant_id       => tenant,
        :client_id       => app_ident,
        :client_secret   => secret_key,
        :subscription_id => sub_id,
        :environment     => 'AzureCloud'
      )
    end

    def rg_client
      # noinspection RubyArgCount
      @rg_client ||= Fog::Resources::AzureRM.new(
        tenant_id:       tenant,
        client_id:       app_ident,
        client_secret:   secret_key,
        subscription_id: sub_id,
        :environment     => 'AzureCloud'
      )
    end

    def storage_client
      @storage_client ||= Fog::Storage.new(
        :provider        => 'AzureRM',
        :tenant_id       => tenant,
        :client_id       => app_ident,
        :client_secret   => secret_key,
        :subscription_id => sub_id,
        :environment     => 'AzureCloud'
      )
    end

    def azure_network_service
      # noinspection RubyArgCount
      @azure_network_service ||= Fog::Network::AzureRM.new(
        :tenant_id       => tenant,
        :client_id       => app_ident,
        :client_secret   => secret_key,
        :subscription_id => sub_id,
        :environment     => 'AzureCloud'
      )
    end

    def azure_nic(interface_card_id)
      azure_network_service.network_interfaces.get(
        interface_card_id.split('/')[4],
        interface_card_id.split('/')[-1]
      )
    end
  end
end
