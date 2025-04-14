# app/models/sale_order_item.rb
class SaleOrderItem < ApplicationRecord
  belongs_to :sale_order
  has_one :sale_order_item_supply, dependent: :destroy

  after_save :sync_suppliers, if: :produto_id_changed?

  validates :produto_id, :quantidade, :valor_unitario, presence: true

  def sync_suppliers
    SaleOrderItemSupply.sync_from_bling(self, produto_id)
  end
end