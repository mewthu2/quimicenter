class AddBlingFieldsToSaleOrderItem < ActiveRecord::Migration[7.2]
  def change
    add_column :sale_order_items, :bling_order_id, :string
    add_column :sale_order_items, :bling_numero, :string
    add_column :sale_order_items, :purchase_order_created_at, :datetime
  end
end