module AzureRmTestHelper
  def mock_sdk_results
    @mock_vm = mock('mock_vm')
    @mock_vm.stubs(:location).returns('eastus')
    @mock_vm.stubs(:name).returns('ervin-golomb')
    mock_network_profile = mock('mock_network_profile')
    @mock_vm.stubs(:network_profile).returns(mock_network_profile)
    mock_network_interfaces = mock('mock_network_interfaces')
    mock_network_profile.stubs(:network_interfaces).returns([mock_network_interfaces])
    mock_network_interfaces.stubs(:id).returns('nic_id')
    mock_vm_nic = mock('mock_vm_nic')
    @mock_sdk.stubs(:vm_nic).returns(mock_vm_nic)



    mock_hardware_profile = mock('mock_hardware_profile')
    @mock_vm.stubs(:hardware_profile).returns(mock_hardware_profile)

    mock_os_profile = mock('mock_os_profile')
    @mock_vm.stubs(:os_profile).returns(mock_os_profile)
    mock_linux_configuration = mock('mock_linux_configuration')
    mock_os_profile.stubs(:linux_configuration).returns(mock_linux_configuration)
    mock_ssh = mock('mock_ssh')
    mock_linux_configuration.stubs(:ssh).returns(mock_ssh)
    mock_public_key = mock('mock_public_key')
    mock_ssh.stubs(:public_keys).returns([mock_public_key])
    mock_os_profile.stubs(:admin_password).returns('testpswd123')


    mock_storage_profile = mock('mock_storage_profile')
    @mock_vm.stubs(:storage_profile).returns(mock_storage_profile)
    mock_img_ref = mock('mock_img_ref')
    mock_storage_profile.stubs(:image_reference).returns(mock_img_ref)
    mock_img_ref.stubs(:publisher)
    mock_img_ref.stubs(:offer)
    mock_img_ref.stubs(:sku)
    mock_img_ref.stubs(:version)
    mock_os_disk = mock('mock_os_disk')
    mock_storage_profile.stubs(:os_disk).returns(mock_os_disk)
    mock_managed_disk = mock('mock_managed_disk')
    mock_os_disk.stubs(:managed_disk).returns(mock_managed_disk)
    mock_data_disk = mock('mock_data_disk')
    mock_storage_profile.stubs(:data_disks).returns([mock_data_disk])
    @mock_sdk.stubs(:fetch_gallery_image_id).with("rg1", "ssfegre").returns('first_gallery_img_id')

    mock_vnet = mock('mock_vnet')
    @mock_sdk.expects(:vnets).returns([mock_vnet])
    mock_vnet.stubs(:location).returns('eastus')
    mock_vnet.stubs(:resource_group).returns('rg1')
    mock_vnet.stubs(:name).returns('first_vnet')
    mock_subnets = mock('mock_subnets')
    @mock_sdk.expects(:subnets).with('rg1', 'first_vnet').returns([mock_subnets])
    mock_subnets.stubs(:id).returns('subnet_id')
    mock_nic = mock('mock_nic')
    vm_nic = @mock_sdk.expects(:create_or_update_nic).with() do |p1, p2|
      p1 == "rg1" &&
      p2 == "ervin-golomb-nic0"
    end
    vm_nic.returns(mock_nic)
    mock_nic.stubs(:id).returns('nic_id')
    mock_pip = mock('mock_pip')
    vm_pip = @mock_sdk.expects(:create_or_update_pip).with() do |p1, p2|
      p1 == "rg1"
      p2 == "ervin-golomb-pip0"
    end
    vm_pip.returns(mock_pip)
  end

  def mock_create_or_update_vm_with_password
    vm_password = @mock_sdk.expects(:create_or_update_vm).with() do
      |actual_rg, actual_vm_name, actual_vm_params|
      actual_rg == "rg1" &&
      actual_vm_name == "ervin-golomb" &&
      actual_vm_params.os_profile.computer_name == "ervin-golomb" &&
      actual_vm_params.os_profile.linux_configuration.ssh.public_keys.count == 1
    end
    vm_password.returns(@mock_vm)
  end

  def mock_create_or_update_vm_with_sshkey
    vm_ssh_update = @mock_sdk.expects(:create_or_update_vm).with() do
      |actual_rg, actual_vm_name, actual_vm_params|
      actual_rg == "rg1" &&
      actual_vm_name == "ervin-golomb" &&
      actual_vm_params.os_profile.computer_name == "ervin-golomb" &&
      actual_vm_params.os_profile.linux_configuration.ssh.public_keys.count == 2
    end
    vm_ssh_update.returns(@mock_vm)
  end

  # rubocop:disable Layout/LineLength
  def base_vm_args
    {
        "location" => "eastus",
        "resource_group" => "rg1",
        "vm_size" => "Standard_A0",
        "platform" => "Linux",
        "username" => "testuser",
        "name" => "ervin-golomb.example.com",
        "interfaces_attributes" => {
            "0" => {
"network" => "[\"/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg1/providers/Microsoft.Network/virtualNetworks/first_vnet/subnets/first_subnet\"]", "public_ip" => "Dynamic", "private_ip" => "false"}
        }
    }
  end
  # rubocop:enable Layout/LineLength

  def with_password_auth
    {
        "disable_password_authentication" => "false",
        "password" => "testpswd123",
    }
  end

  def with_marketplace_image
    { "image_id" => "marketplace://OpenLogic:CentOS:7.5:latest" }
  end

  def with_custom_image
    { "image_id" => "custom://first_custom_img" }
  end

  def with_gallery_image
    { "image_id" => "gallery://first_gallery_img" }
  end

  def with_custom_data
    { "user_data" => "echo customData" }
  end

  def with_vm_extensions
    {
        "script_command" => "sudo sh /var/lib/waagent/custom-script/download/0/myscript.sh",
        "script_uris" => "https://gist.githubusercontent.com/apuntamb/f4e9ff4e2daf62bc847313b0c64e59f9/raw/73578e1bb7b03237ae1ac6b787b08d00d126adf0/myscript.sh",
    }
  end

  def with_ssh_key_auth
    {
        "disable_password_authentication" => "true",
        "ssh_key_data" => "MIIBIjANBgk\nPwIDAQAB"
    }
  end
end
