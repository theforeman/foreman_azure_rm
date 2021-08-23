class FixCaseAzureRm < ActiveRecord::Migration[5.2]
  def change
    foreman_rm_change = "ForemanAzureRm::AzureRm"
    ComputeResource.where(type: 'ForemanAzureRM::AzureRM').update_all(type: foreman_rm_change)
  end
end
