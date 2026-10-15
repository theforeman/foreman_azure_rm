require 'foreman_azure_rm/engine.rb'

module ForemanAzureRm
  module ComputeModels
    module CachingTypes
      None = 'None'.freeze
      ReadOnly = 'ReadOnly'.freeze
      ReadWrite = 'ReadWrite'.freeze
    end

    module DiskCreateOption
      Empty = 'Empty'.freeze
    end

    module DiskCreateOptionTypes
      FromImage = 'FromImage'.freeze
    end

    module StorageAccountTypes
      PremiumLRS = 'Premium_LRS'.freeze
      StandardLRS = 'Standard_LRS'.freeze
    end
  end

  module NetworkModels
    module IPAllocationMethod
      Dynamic = 'Dynamic'.freeze
      Static = 'Static'.freeze
    end
  end
end
