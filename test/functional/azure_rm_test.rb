require_relative '../test_plugin_helper'

module ForemanAzureRM
  class ComputeResourcesControllerTest < ActionController::TestCase
    tests ::ComputeResourcesController

    setup { Fog.mock! }
    teardown { Fog.unmock! }

    test "should create a compute resource and return edit page" do
      test_client = Fog::Resources::AzureRM.new(
        tenant_id:       '',
        client_id:       '',
        client_secret:   '',
        subscription_id: '',
        :environment     => 'AzureCloud')

      ForemanAzureRM::AzureRM.any_instance.stubs(:rg_client).returns(test_client)
      test_client.stubs(:list_resource_groups).returns([])
      @compute_resource =  FactoryBot.create(:azure_cr)

      get :edit, params: { :id => @compute_resource.to_param }, session: set_session_user
      assert_response :success
      assert_template 'edit'
    end
  end
end
