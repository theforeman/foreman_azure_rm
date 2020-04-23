require_relative '../test_plugin_helper'

module ForemanAzureRm
  class ForemanAzureRmTest < ActiveSupport::TestCase

    setup do
      @test_sdk = mock('test_sdk') #creates an empty object
      ForemanAzureRm::AzureRm.any_instance.stubs(:sdk).returns(@test_sdk)
      @azure_cr = FactoryBot.build(:azure_rm)
      @azure_cr.stubs(:sdk).returns(@test_sdk)
    end

    test "list all valid regions" do
      @test_region_sdk = mock('test_region_sdk')
      @test_sdk.stubs(:list_regions).with('11111111-1111-1111-1111-111111111111').returns(@test_region_sdk)
      @eastus_region = mock('eastus_region')
      @westus_region = mock('westus_region')
      @test_region_sdk.stubs(:value).returns([@eastus_region, @westus_region])
      @eastus_region.stubs(:display_name => 'East US', :name => 'eastus')
      @westus_region.stubs(:display_name => 'West US', :name => 'westus')
      assert_equal [['East US', 'eastus'], ['West US', 'westus']], @azure_cr.regions
    end

    test "list all resource groups" do
      @test_resource_client = mock('test_resource_client')
      @test_sdk.stubs(:resource_client).returns(@test_resource_client)
      @test_sdk.stubs(:rgs).returns(['rg1', 'rg2', 'rg3'])
      assert ['rg1', 'rg2', 'rg3'], @azure_cr.resource_groups
    end
  end
end
