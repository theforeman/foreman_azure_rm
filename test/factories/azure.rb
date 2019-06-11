FactoryBot.define do
  factory :azure_rm, :parent => :compute_resource, :class => ForemanAzureRM::AzureRM do
    add_attribute(:user) { 'azurermuser' }
    add_attribute(:password) { 'azurermpassword' }
    add_attribute(:url) { 'http://azurerm.example.com' }
    add_attribute(:uuid) { 'azurermuuid' }
  end
end
