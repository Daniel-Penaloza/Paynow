class SetExistingOrganizationPlansToActive < ActiveRecord::Migration[8.0]
  def up
    # Organizations created before the plan system are grandfathered as active
    Organization.where(plan_status: "trialing", trial_ends_at: nil).update_all(plan_status: "active")
  end

  def down
    Organization.where(plan_status: "active", trial_ends_at: nil).update_all(plan_status: "trialing")
  end
end
