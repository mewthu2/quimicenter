class AddProdutoEstoqueToSaleOrderItem < ActiveRecord::Migration[7.2]
  def change
    add_column :sale_order_items, :produto_estoque, :integer
  end
end