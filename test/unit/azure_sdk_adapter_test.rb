require_relative '../test_plugin_helper'

module ForemanAzureRm
  class AzureSdkAdapterTest < ActiveSupport::TestCase
    setup do
      compute_resource = FactoryBot.build(:azure_rm)
      tenant           = compute_resource.uuid
      app_ident        = compute_resource.app_ident
      secret_key       = compute_resource.password
      sub_id           = compute_resource.user
      @test_adapter    = AzureSdkAdapter.new(tenant, app_ident, secret_key, sub_id)
      AzureSdkAdapter.stubs(:gallery_caching).with('test_rg').returns({})
    end

    test "should call #actual_gallery_image_id when #gallery_caching is {} otherwise return #gallery_caching" do
      @test_adapter.expects(:actual_gallery_image_id).with('test_rg', 'test_gallery_image_name').once.returns('test_gallery_img_id')
      actual1 = @test_adapter.fetch_gallery_image_id('test_rg', 'test_gallery_image_name')
      actual2 = @test_adapter.fetch_gallery_image_id('test_rg', 'test_gallery_image_name')

      assert_equal actual1, actual2
      assert_equal 'test_gallery_img_id', actual1
    end
  end
end
