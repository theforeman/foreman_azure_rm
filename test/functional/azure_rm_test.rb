require_relative '../test_plugin_helper'

module ForemanAzureRM
  class ComputeResourcesControllerTest < ActionController::TestCase
    tests ::ComputeResourcesController

    setup do
      @test_sdk = mock('test_sdk') #creates an empty object
      ForemanAzureRM::AzureRM.any_instance.stubs(:sdk).returns(@test_sdk)
      @test_resource_client = mock('resource_client')
      @test_sdk.stubs(:resource_client).returns(@test_resource_client)
    end

    test "should return compute resource edit page" do
      @test_sdk.stubs(:rgs).returns(['a', 'b', 'c'])
      compute_resource = FactoryBot.create(:azure_rm)
      get :edit, params: { :id => compute_resource.to_param }, session: set_session_user
      assert_response :success
      assert_template 'edit'
    end
  end
end
