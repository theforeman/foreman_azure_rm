class FixImageUuidPrefix < ActiveRecord::Migration[5.2]
  def up
    marketplace_uuid = "uuid = concat('marketplace://', uuid)"
    Image.where(compute_resource: ForemanAzureRm::AzureRm.unscoped.all).update_all(marketplace_uuid)
  end

  def down
  end
end
