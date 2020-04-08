require_relative '../test_plugin_helper'

module ForemanAzureRm
  class ForemanAzureRmTest < ActiveSupport::TestCase

    setup do
      @test_sdk = mock('test_sdk') #creates an empty object
      ForemanAzureRm::AzureRm.any_instance.stubs(:sdk).returns(@test_sdk)
    end

    def new_azurerm_cr
      FactoryBot.build(:azure_rm)
    end

    test "list all valid regions" do
      @test_sub_client = mock('test_subscription_client')
      @test_sdk.stubs(:subscription_client).returns(@test_sub_client)
      check_regions = @test_sdk.stubs(:list_regions).with('jnfurejefjes')
      check_regions.stubs(:value).returns(['loc1', 'loc2', 'loc3'])
      assert check_regions.value
    end

    test "list all resource groups" do
      @test_resource_client = mock('test_resource_client')
      @test_sdk.stubs(:resource_client).returns(@test_resource_client)
      @test_sdk.stubs(:rgs).returns(['rg1', 'rg2', 'rg3'])
      assert @test_sdk.rgs
    end
  end
end
