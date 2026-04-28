class CreateBusinesses < ActiveRecord::Migration[8.0]
  def change
    create_table :businesses do |t|
      t.string :name
      t.string :clabe
      t.string :holder_name
      t.string :whatsapp
      t.text :instructions
      t.string :slug
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :businesses, :slug, unique: true
  end
end
