require_relative '../test_plugin_helper'

class ManagedVMTest < ActiveSupport::TestCase
  # Create a test class that includes the ManagedVM concern
  class TestVMExtensions
    include ForemanAzureRm::VMExtensions::ManagedVM
  end

  setup do
    @vm_extensions = TestVMExtensions.new
  end

  # Tests for SAT-48157 - Marketplace Plan Bug Fix

  test "should create plan for marketplace image without byos" do
    # Test with CIS marketplace image from SAT-48157
    image = "marketplace://center-for-internet-security-inc:cis-rhel:cis-redhat9-l1-gen2:latest"

    plan = @vm_extensions.marketplace_image_plan(image)

    assert_not_nil plan, "Plan should be created for non-BYOS marketplace images"
    assert_equal "center-for-internet-security-inc", plan.publisher
    assert_equal "cis-rhel", plan.product
    assert_equal "cis-redhat9-l1-gen2", plan.name
  end

  test "should create plan for marketplace image with byos" do
    image = "marketplace://publisher:offer-byos:sku:latest"

    plan = @vm_extensions.marketplace_image_plan(image)

    assert_not_nil plan, "Plan should be created for BYOS marketplace images"
    assert_equal "publisher", plan.publisher
    assert_equal "offer-byos", plan.product
    assert_equal "sku", plan.name
  end

  test "should create plan for standard marketplace image" do
    # Standard OpenLogic CentOS image
    image = "marketplace://OpenLogic:CentOS:7.5:latest"

    plan = @vm_extensions.marketplace_image_plan(image)

    assert_not_nil plan, "Plan should be created for all marketplace images"
    assert_equal "openlogic", plan.publisher
    assert_equal "centos", plan.product
    assert_equal "7.5", plan.name
  end

  test "should return nil for non-marketplace images" do
    # Custom image
    custom_image = "custom://my-custom-image"
    plan = @vm_extensions.marketplace_image_plan(custom_image)
    assert_nil plan, "Plan should not be created for custom images"

    # Gallery image
    gallery_image = "gallery://RHSG_1/RHEL77img"
    plan = @vm_extensions.marketplace_image_plan(gallery_image)
    assert_nil plan, "Plan should not be created for gallery images"
  end

  test "should handle plan values as lowercase" do
    image = "marketplace://PUBLISHER:OFFER:SKU:latest"

    plan = @vm_extensions.marketplace_image_plan(image)

    assert_equal "publisher", plan.publisher, "Publisher should be lowercase"
    assert_equal "offer", plan.product, "Product should be lowercase"
    assert_equal "sku", plan.name, "Name should be lowercase"
  end
end
