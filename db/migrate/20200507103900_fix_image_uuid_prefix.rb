class FixImageUuidPrefix < ActiveRecord::Migration[5.2]
  def change
    Image.where(compute_resource: ForemanAzureRm::AzureRm.unscoped.all).update_all("uuid = concat('marketplace://', uuid)")
  end
end
