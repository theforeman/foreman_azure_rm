require File.expand_path('lib/foreman_azure_rm/version', __dir__)
require 'date'

Gem::Specification.new do |s|
  s.name    = 'foreman_azure_rm'
  s.version = ForemanAzureRm::VERSION
  s.authors = ['Aditi Puntambekar', 'Shimon Shtein', 'Tyler Gregory']
  s.email   = ['puntambekaraditi@gmail.com', 'shteinshim@gmail.com', 'tdgregory@protonmail.com']
  s.summary = 'Azure Resource Manager as a compute resource for The Foreman'
  s.homepage = 'https://github.com/theforeman/foreman_azure_rm'
  s.license = 'GPL-3.0'
  s.files   = Dir['{app,config,db,lib,locale}/**/*'] + ['LICENSE', 'Rakefile', 'README.md']
  s.description = 'This gem provides Azure Resource Manager as a compute resource for The Foreman'

  s.add_dependency 'azure_mgmt_resources', '~> 0.18.1'
  s.add_dependency 'azure_mgmt_network', '~> 0.26.1'
  s.add_dependency 'azure_mgmt_storage', '~> 0.23.0'
  s.add_dependency 'azure_mgmt_compute', '~> 0.22.0'
  s.add_dependency 'azure_mgmt_subscriptions', '~> 0.18.5'
end
