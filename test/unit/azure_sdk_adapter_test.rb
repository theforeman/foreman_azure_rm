require_relative '../test_plugin_helper'

class AzureSdkAdapterTest < ActiveSupport::TestCase
  setup do
    compute_resource = FactoryBot.build(:azure_rm)
    tenant           = compute_resource.uuid
    app_ident        = compute_resource.app_ident
    secret_key       = compute_resource.password
    sub_id           = compute_resource.user
    cloud            = compute_resource.cloud
    @test_adapter    = ForemanAzureRm::AzureSdkAdapter.new(tenant, app_ident, secret_key, sub_id, cloud)
    ForemanAzureRm::AzureSdkAdapter.stubs(:gallery_caching).with('test_rg').returns({})
  end

  test "should call #actual_gallery_image_id when #gallery_caching is {} otherwise return #gallery_caching" do
    @test_adapter.expects(:actual_gallery_image_id).with('test_rg', 'test_gallery_image_name').once.returns('test_gallery_img_id')
    actual1 = @test_adapter.fetch_gallery_image_id('test_rg', 'test_gallery_image_name')
    actual2 = @test_adapter.fetch_gallery_image_id('test_rg', 'test_gallery_image_name')

    assert_equal actual1, actual2
    assert_equal 'test_gallery_img_id', actual1
  end
end

# Test for SAT-48157 - Gallery image bug fix
test "should correctly parse gallery name and image name from image_id" do
  # Mock the list_gallery_images to return a test gallery image
  mock_gallery_image = mock('mock_gallery_image')
  mock_gallery_image.stubs(:name).returns('RHEL77img')
  mock_gallery_image.stubs(:id).returns('/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/galleries/RHSG_1/images/RHEL77img')

  @test_adapter.expects(:list_gallery_images).with('test_rg', 'RHSG_1').returns([mock_gallery_image])

  # Test with format: gallery_name/image_name
  result = @test_adapter.actual_gallery_image_id('test_rg', 'RHSG_1/RHEL77img')

  assert_equal '/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.Compute/galleries/RHSG_1/images/RHEL77img', result
end

test "should return nil when gallery image is not found" do
  # Mock list_gallery_images to return empty array
  @test_adapter.expects(:list_gallery_images).with('test_rg', 'NonExistentGallery').returns([])

  result = @test_adapter.actual_gallery_image_id('test_rg', 'NonExistentGallery/NonExistentImage')

  assert_nil result
end

test "should return nil when image_id format is invalid" do
  # No gallery name separator
  result = @test_adapter.actual_gallery_image_id('test_rg', 'invalid_format')

  assert_nil result
end

test "should handle exceptions gracefully in actual_gallery_image_id" do
  @test_adapter.expects(:list_gallery_images).raises(StandardError, 'Azure API error')

  result = @test_adapter.actual_gallery_image_id('test_rg', 'RHSG_1/RHEL77img')

  assert_nil result
end
