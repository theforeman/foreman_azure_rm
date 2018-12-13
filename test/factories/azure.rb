FactoryBot.define do
    factory :azure_cr, :parent => :compute_resource, :class => ForemanAzureRM::AzureRM do
      provider 'AzureRM'
      user 'azurermuser'
      password 'azurermpassword'
      url 'http://azurerm.example.com'
      uuid 'azurermuuid'
    end
end
