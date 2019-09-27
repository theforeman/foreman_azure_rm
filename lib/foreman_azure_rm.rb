require 'foreman_azure_rm/engine.rb'
require 'azure_mgmt_resources'
require 'azure_mgmt_network'
require 'azure_mgmt_storage'
require 'azure_mgmt_compute'

module ForemanAzureRM
  Storage = Azure::Storage::Profiles::Latest::Mgmt
  Network = Azure::Network::Profiles::Latest::Mgmt
  Compute = Azure::Compute::Profiles::Latest::Mgmt
  Resources = Azure::Resources::Profiles::Latest::Mgmt

  StorageModels = Storage::Models
  NetworkModels = Network::Models
  ComputeModels = Compute::Models
  ResourceModels = Resources::Models
end