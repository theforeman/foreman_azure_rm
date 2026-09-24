require File.expand_path('lib/foreman_azure_rm/version', __dir__)
require 'date'

Gem::Specification.new do |s|
  s.name    = 'foreman_azure_rm'
  s.version = ForemanAzureRm::VERSION
  s.authors = ['Aditi Puntambekar', 'Shimon Shtein', 'Tyler Gregory']
  s.email   = ['puntambekaraditi@gmail.com', 'shteinshim@gmail.com', 'tdgregory@protonmail.com']
  s.summary = 'Microsoft Azure plugin for Foreman'
  s.homepage = 'https://github.com/theforeman/foreman_azure_rm'
  s.license = 'GPL-3.0'
  s.files   = Dir['{app,config,db,lib,locale}/**/*'] + ['LICENSE', 'Rakefile', 'README.md']
  s.description = 'This gem provides Microsoft Azure as a compute resource for Foreman'

  # Azure SDK for Ruby was retired (Dec 2021, archived Jan 2023).
  # This plugin now uses direct Azure REST API calls via Net::HTTP.
end
