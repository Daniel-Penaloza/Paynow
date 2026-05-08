class AddPlanFieldsToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :plan, :string, default: "free", null: false
    add_column :organizations, :plan_status, :string, default: "trialing", null: false
    add_column :organizations, :trial_ends_at, :date
    add_column :organizations, :current_period_ends_at, :date
  end
end
