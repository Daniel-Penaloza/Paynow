class AddRoleAndOrganizationToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :integer
    add_reference :users, :organization, null: true, foreign_key: true
  end
end
