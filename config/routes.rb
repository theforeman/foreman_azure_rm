Rails.application.routes.draw do
  scope :azure_rm, :path => '/azure_rm' do
    get :sizes, :controller => :hosts
  end
end