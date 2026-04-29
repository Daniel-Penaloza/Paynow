class AddExtractionFieldsToReceipts < ActiveRecord::Migration[8.0]
  def change
    add_column :receipts, :amount_cents, :integer
    add_column :receipts, :transfer_date, :date
    add_column :receipts, :bank_name, :string
    add_column :receipts, :reference_number, :string
    add_column :receipts, :verification_status, :string, default: "pending", null: false
    add_column :receipts, :verification_notes, :text
  end
end
