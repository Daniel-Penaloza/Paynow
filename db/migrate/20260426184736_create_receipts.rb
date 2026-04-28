class CreateReceipts < ActiveRecord::Migration[8.0]
  def change
    create_table :receipts do |t|
      t.references :business, null: false, foreign_key: true
      t.datetime :submitted_at

      t.timestamps
    end
  end
end
