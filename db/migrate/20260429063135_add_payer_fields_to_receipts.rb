class AddPayerFieldsToReceipts < ActiveRecord::Migration[8.0]
  def change
    add_column :receipts, :payer_name, :string
    add_column :receipts, :payer_phone, :string
  end
end
