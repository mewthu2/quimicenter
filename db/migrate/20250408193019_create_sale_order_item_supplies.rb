class CreateSaleOrderItemSupplies < ActiveRecord::Migration[7.2]
  def change
    create_table :sale_order_item_supplies do |t|
      t.references :sale_order_item, null: false, foreign_key: true
      t.bigint :supplier_id, null: false
      t.string :supplier_name
      t.string :supplier_type
      t.boolean :default, default: false
      t.datetime :last_sync_at

      t.timestamps
    end

    add_index :sale_order_item_supplies, :supplier_id
    add_index :sale_order_item_supplies, [:sale_order_item_id, :supplier_id], unique: true, name: 'index_item_supplier_unique'
  end
end