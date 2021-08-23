require_relative '../test_plugin_helper'
require_relative '../azure_rm_test_helper'
# rubocop:disable Layout/LineLength

module ForemanAzureRm
  class ForemanAzureRmTest < ActiveSupport::TestCase
    include AzureRmTestHelper
    setup do
      @mock_sdk = mock('mock_sdk')
      ForemanAzureRm::AzureRm.any_instance.stubs(:sdk).returns(@mock_sdk)
      mock_region_sdk = mock('mock_region_sdk')
      @mock_sdk.stubs(:list_regions).with('11111111-1111-1111-1111-111111111111').returns(mock_region_sdk)
      eastus_region = mock('eastus_region')
      westus_region = mock('westus_region')
      mock_region_sdk.stubs(:value).returns([eastus_region, westus_region])
      eastus_region.stubs(:display_name => 'East US', :name => 'eastus')
      westus_region.stubs(:display_name => 'West US', :name => 'westus')

      @azure_cr = FactoryBot.create(:azure_rm)
      @azure_cr.stubs(:sdk).returns(@mock_sdk)
    end

    test "list all valid regions" do
      assert_equal [['East US', 'eastus'], ['West US', 'westus']], @azure_cr.regions
    end

    test "list valid standard cloud name" do
      cloud = %w[azure azureusgovernment azurechina azuregermancloud].sample
      ForemanAzureRm::AzureRm.any_instance.stubs(:validate_cloud?).returns(true)
      @azure_cr.cloud=(cloud)
      assert @azure_cr.validate_cloud?
    end

    test "list all resource groups" do
      mock_resource_client = mock('mock_resource_client')
      @mock_sdk.stubs(:resource_client).returns(mock_resource_client)
      @mock_sdk.stubs(:rgs).returns(['rg1', 'rg2', 'rg3'])
      assert ['rg1', 'rg2', 'rg3'], @azure_cr.resource_groups
    end

    # rubocop:disable Metrics/BlockLength
    context 'sdk access' do
      setup do
        mock_sdk_results
        @azure_cr.key_pair = @azure_cr.setup_key_pair
      end

      test "create vm with password and without custom data" do
        @mock_vm.stubs(:disable_password_authentication).returns(false)
        @mock_vm.os_profile.stubs(:custom_data)
        mock_vm_extension = mock('mock_vm_extension')
        vm_extension = @mock_sdk.expects(:create_or_update_vm_extensions).with() do |actual_rg, vm_name, script_name, actual_ext|
          actual_rg == "rg1" &&
          actual_ext.settings["commandToExecute"] == "$echo testpswd123 | sudo -S echo '\"testuser\" ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/waagent"
        end
        vm_extension.returns(mock_vm_extension)
        mock_create_or_update_vm_with_password
        vm_args = base_vm_args.merge(with_password_auth).merge(with_marketplace_image)
        actual_server = @azure_cr.create_vm(vm_args)

        assert_equal "ervin-golomb", actual_server.name
        assert_equal "rg1", actual_server.resource_group
        assert actual_server.password.present?
        assert_equal 1, actual_server.interfaces.count
        refute actual_server.azure_vm.disable_password_authentication
        refute actual_server.azure_vm.os_profile.custom_data.present?
      end

      test "create vm with password, custom data and vm extension" do
        @mock_vm.stubs(:disable_password_authentication).returns(false)
        @mock_vm.os_profile.stubs(:custom_data).returns('ZWNobyBjdXN0b21EYXRh')
        mock_create_or_update_vm_with_password
        mock_vm_extension = mock('mock_vm_extension')
        vm_extension = @mock_sdk.expects(:create_or_update_vm_extensions).with() do |actual_rg, vm_name, script_name, actual_ext|
          actual_rg == "rg1" &&
          actual_ext.settings["commandToExecute"] == "$echo testpswd123 | sudo -S echo '\"testuser\" ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/waagent ; su - \"testuser\" -c \"sudo sh /var/lib/waagent/custom-script/download/0/myscript.sh\"" &&
          actual_ext.settings["fileUris"] == ["https://gist.githubusercontent.com/apuntamb/f4e9ff4e2daf62bc847313b0c64e59f9/raw/73578e1bb7b03237ae1ac6b787b08d00d126adf0/myscript.sh"]
        end
        vm_extension.returns(mock_vm_extension)
        vm_args = base_vm_args.merge(with_password_auth).merge(with_custom_data).merge(with_marketplace_image).merge(with_vm_extensions)
        actual_server = @azure_cr.create_vm(vm_args)

        assert_equal "testpswd123", actual_server.password
        assert actual_server.azure_vm.os_profile.custom_data.present?
        refute actual_server.azure_vm.disable_password_authentication
      end

      test "create vm with sshkey and without custom data" do
        @mock_vm.stubs(:disable_password_authentication).returns(true)
        @mock_vm.os_profile.stubs(:custom_data)
        @mock_sdk.expects(:create_or_update_vm_extensions).never
        mock_create_or_update_vm_with_sshkey
        vm_args = base_vm_args.merge(with_ssh_key_auth).merge(with_marketplace_image)
        actual_server = @azure_cr.create_vm(vm_args)

        assert actual_server.azure_vm.disable_password_authentication
        refute actual_server.azure_vm.os_profile.custom_data.present?
      end

      test "create vm with sshkey, custom data and vm extension" do
        @mock_vm.stubs(:disable_password_authentication).returns(true)
        @mock_vm.os_profile.stubs(:custom_data).returns('ZWNobyBjdXN0b21EYXRh')
        mock_create_or_update_vm_with_sshkey
        mock_vm_extension = mock('mock_vm_extension')
        vm_extension = @mock_sdk.expects(:create_or_update_vm_extensions).with() do |actual_rg, vm_name, script_name, actual_ext|
          actual_rg == "rg1" &&
          actual_ext.settings["commandToExecute"] == "sudo sh /var/lib/waagent/custom-script/download/0/myscript.sh" &&
          actual_ext.settings["fileUris"] == ["https://gist.githubusercontent.com/apuntamb/f4e9ff4e2daf62bc847313b0c64e59f9/raw/73578e1bb7b03237ae1ac6b787b08d00d126adf0/myscript.sh"]
        end
        vm_extension.returns(mock_vm_extension)
        vm_args = base_vm_args.merge(with_ssh_key_auth).merge(with_marketplace_image).merge(with_custom_data).merge(with_vm_extensions)
        actual_server = @azure_cr.create_vm(vm_args)

        assert actual_server.azure_vm.disable_password_authentication
        assert actual_server.azure_vm.os_profile.custom_data.present?
      end

      test "create vm with custom image and sshkey" do
        @mock_vm.stubs(:disable_password_authentication).returns(true)
        mock_custom_img = mock('mock_custom_img')
        @mock_sdk.expects(:get_custom_image).with("rg1",
                                                  "first_custom_img").returns(mock_custom_img)
        mock_custom_img.stubs(:name).returns('first_custom_img')
        mock_custom_img.stubs(:id).returns('/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg1/providers/Microsoft.Compute/images/first_custom_img')
        @mock_vm.storage_profile.image_reference.stubs(:id).returns('/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg1/providers/Microsoft.Compute/images/first_custom_img')
        @mock_sdk.stubs(:list_custom_images).returns([mock_custom_img])
        mock_create_or_update_vm_with_sshkey
        @mock_sdk.expects(:create_or_update_vm_extensions).never
        vm_args = base_vm_args.merge(with_ssh_key_auth).merge(with_custom_image)
        actual_server = @azure_cr.create_vm(vm_args)

        assert actual_server.azure_vm.disable_password_authentication
        assert_equal "custom://first_custom_img", actual_server.image_id
      end


      test "create vm with shared image gallery and password" do
        @mock_vm.stubs(:disable_password_authentication).returns(false)
        @mock_sdk.expects(:fetch_gallery_image_id).with("rg1",
                                                        "first_gallery_img").returns("/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg1/providers/Microsoft.Compute/galleries/first_gallery/images/first_gallery_img").times(2)
        mock_gallery_image = mock('mock_gallery_image')
        mock_gallery_image.stubs(:id).returns('/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg1/providers/Microsoft.Compute/galleries/first_gallery/images/first_gallery_img')
        @mock_vm.storage_profile.image_reference.stubs(:id).returns('/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg1/providers/Microsoft.Compute/galleries/first_gallery/images/first_gallery_img')
        @mock_sdk.stubs(:list_custom_images).returns([])
        mock_create_or_update_vm_with_password
        mock_vm_extension = mock('mock_vm_extension')
        vm_extentsion = @mock_sdk.expects(:create_or_update_vm_extensions).with() do |actual_rg, vm_name, script_name, actual_ext|
          actual_rg == "rg1" &&
          actual_ext.settings["commandToExecute"] == "$echo testpswd123 | sudo -S echo '\"testuser\" ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/waagent"
        end
        vm_extentsion.returns(mock_vm_extension)
        vm_args = base_vm_args.merge(with_password_auth).merge(with_gallery_image)
        actual_server = @azure_cr.create_vm(vm_args)

        refute actual_server.azure_vm.disable_password_authentication
        assert_equal "testpswd123", actual_server.password
        assert_equal "gallery://first_gallery_img", actual_server.image_id
      end
    end
  end
  # rubocop:enable Metrics/BlockLength
end
# rubocop:enable Layout/LineLength
