class AddFieldsToSaleOrderItems < ActiveRecord::Migration[7.2]
  def change
    add_column :sale_order_items, :checked_order, :boolean, default: false
    add_column :sale_order_items, :ignore_order, :boolean, default: false
    add_column :sale_order_items, :quantity_order, :string
  end
end