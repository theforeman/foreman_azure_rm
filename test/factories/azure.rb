FactoryBot.define do
  factory :azure_rm, :parent => :compute_resource, :class => ForemanAzureRM::AzureRM do
    add_attribute(:user) { '11111111-1111-1111-1111-111111111111' }
    add_attribute(:password) { '22222222-2222-2222-2222-222222222222' }
    add_attribute(:app_ident) { '33333333-3333-3333-3333-333333333333' }
    add_attribute(:uuid) { '44444444-4444-4444-4444-444444444444' }
    add_attribute(:url) { 'eastus' }
  end
end
