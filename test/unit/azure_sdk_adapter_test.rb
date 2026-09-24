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
    ForemanAzureRm::AzureSdkAdapter.instance_variable_set(:@gallery_cache, {})
  end

  test "caches gallery image ID lookups" do
    @test_adapter.expects(:actual_gallery_image_id).with(nil, 'test_gallery_image_name').once.returns('test_gallery_img_id')
    actual1 = @test_adapter.fetch_gallery_image_id(nil, 'test_gallery_image_name')
    actual2 = @test_adapter.fetch_gallery_image_id(nil, 'test_gallery_image_name')

    assert_equal actual1, actual2
    assert_equal 'test_gallery_img_id', actual1
  end

  test "resolves canonical 3-part gallery image ID directly" do
    gallery_arm_id = '/subscriptions/sub/resourceGroups/rg1/providers/Microsoft.Compute/galleries/mygallery/images/myimage'
    mock_image = stub(name: 'myimage', id: gallery_arm_id)
    @test_adapter.expects(:list_gallery_images).with('rg1', 'mygallery').returns([mock_image])

    result = @test_adapter.send(:actual_gallery_image_id, nil, 'rg1/mygallery/myimage')

    assert_equal gallery_arm_id, result
  end

  test "resolves 2-part gallery image ID when unique" do
    gallery = stub(name: 'mygallery', resource_group: 'rg1', id: '/subscriptions/sub/resourceGroups/rg1/providers/Microsoft.Compute/galleries/mygallery')
    mock_image = stub(name: 'myimage', id: '/subscriptions/sub/resourceGroups/rg1/providers/Microsoft.Compute/galleries/mygallery/images/myimage')
    @test_adapter.expects(:list_galleries).returns([gallery])
    @test_adapter.expects(:list_gallery_images).with('rg1', 'mygallery').returns([mock_image])

    result = @test_adapter.send(:actual_gallery_image_id, nil, 'mygallery/myimage')

    assert_match(/myimage$/, result)
  end

  test "raises on ambiguous 1-part gallery image ID" do
    gallery1 = stub(name: 'gallery1', resource_group: 'rg1', id: '/subscriptions/sub/resourceGroups/rg1/providers/Microsoft.Compute/galleries/gallery1')
    gallery2 = stub(name: 'gallery2', resource_group: 'rg2', id: '/subscriptions/sub/resourceGroups/rg2/providers/Microsoft.Compute/galleries/gallery2')
    img1 = stub(name: 'shared-img', id: 'id1')
    img2 = stub(name: 'shared-img', id: 'id2')
    @test_adapter.expects(:list_galleries).returns([gallery1, gallery2])
    @test_adapter.expects(:list_gallery_images).with('rg1', 'gallery1').returns([img1])
    @test_adapter.expects(:list_gallery_images).with('rg2', 'gallery2').returns([img2])

    assert_raises(ArgumentError) do
      @test_adapter.send(:actual_gallery_image_id, nil, 'shared-img')
    end
  end

  test "gallery cache is scoped per subscription" do
    sub_a = 'subscription-a'
    sub_b = 'subscription-b'

    ForemanAzureRm::AzureSdkAdapter.gallery_cache(sub_a)['myimage'] = 'arm-id-a'
    ForemanAzureRm::AzureSdkAdapter.gallery_cache(sub_b)['myimage'] = 'arm-id-b'

    assert_equal 'arm-id-a', ForemanAzureRm::AzureSdkAdapter.gallery_cache(sub_a)['myimage']
    assert_equal 'arm-id-b', ForemanAzureRm::AzureSdkAdapter.gallery_cache(sub_b)['myimage']
    assert_not_equal ForemanAzureRm::AzureSdkAdapter.gallery_cache(sub_a)['myimage'],
      ForemanAzureRm::AzureSdkAdapter.gallery_cache(sub_b)['myimage']
  end

  test "raises on ambiguous 2-part gallery image ID across resource groups" do
    gallery_rg1 = stub(name: 'shared-gallery', resource_group: 'rg1', id: '/subscriptions/sub/resourceGroups/rg1/providers/Microsoft.Compute/galleries/shared-gallery')
    gallery_rg2 = stub(name: 'shared-gallery', resource_group: 'rg2', id: '/subscriptions/sub/resourceGroups/rg2/providers/Microsoft.Compute/galleries/shared-gallery')
    img1 = stub(name: 'myimage', id: 'id1')
    img2 = stub(name: 'myimage', id: 'id2')
    @test_adapter.expects(:list_galleries).returns([gallery_rg1, gallery_rg2])
    @test_adapter.expects(:list_gallery_images).with('rg1', 'shared-gallery').returns([img1])
    @test_adapter.expects(:list_gallery_images).with('rg2', 'shared-gallery').returns([img2])

    error = assert_raises(ArgumentError) do
      @test_adapter.send(:actual_gallery_image_id, nil, 'shared-gallery/myimage')
    end
    assert_match(/ambiguous/, error.message)
  end
end
