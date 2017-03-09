require File.expand_path('../lib/foreman_azure_rm/version', __FILE__)
require 'date'

Gem::Specification.new do |s|
  s.name    = 'foreman_azure_rm'
  s.version = ForemanAzureRM::VERSION
  s.date    = Date.today.to_s
  s.authors = ['Tyler Gregory']
  s.email   = ['tdgregory@protonmail.com']
  s.summary = 'Azure Resource Manager as a compute resource for The Foreman'
  s.files   = Dir['{app,config,db,lib,locale}/**/*'] + ['LICENSE', 'Rakefile', 'README.md']

  s.add_dependency 'fog-azure-rm', '0.2.7'
  s.add_dependency 'deface', '< 2.0'
end