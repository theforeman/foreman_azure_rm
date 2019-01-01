require_relative 'lib/foreman_azure_rm/version'
require 'date'

Gem::Specification.new do |s|
  s.name    = 'foreman_azure_rm'
  s.version = ForemanAzureRM::VERSION
  s.date    = Date.today.to_s
  s.authors = ['Tyler Gregory']
  s.email   = ['tdgregory@protonmail.com']
  s.summary = 'Azure Resource Manager as a compute resource for The Foreman'
  s.homepage = 'https://github.com/theforeman/foreman_azure_rm'
  s.license = 'GPL-3.0'
  s.files   =
    Dir['{app,config,db,lib,locale}/**/*'] +
    ['LICENSE', 'Rakefile', 'README.md']
  s.description = <<DESC
   This gem provides Azure Resource Manager as a compute resource for The Foreman
DESC

  s.add_dependency 'deface', '< 2.0'
  s.add_dependency 'fog-azure-rm-downgraded', '0.3.1'

  s.add_development_dependency 'rubocop', '~> 0.61.1'
end
