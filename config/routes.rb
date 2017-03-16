Rails.application.routes.draw do
  scope :azure_rm, :path => '/azure_rm' do
    get :sizes, :controller => :hosts
    get :subnets, :controller => :hosts
    get :storage_accts, :controller => :hosts
    get :vnets, :controller => :hosts
  end
end