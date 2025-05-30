# app/models/sale_order_item_supply.rb
class SaleOrderItemSupply < ApplicationRecord
  belongs_to :sale_order_item
  validates :supplier_id, presence: true, uniqueness: { scope: :sale_order_item_id }

  def self.sync_from_bling(sale_order_item, product_id)
    suppliers_data = Bling::ProductSuppliers.list(product_id:)['data'] || []

    last_supplier = suppliers_data.last

    return unless last_supplier

    contact_data = Bling::Contacts.find(last_supplier['fornecedor']['id'])['data'] || {}

    create_or_update(
      sale_order_item:,
      supplier_id: contact_data['id'],
      supplier_name: contact_data['nome'],
      supplier_type: contact_data['tipo'],
      default: last_supplier['padrao'] || false
    )
  rescue StandardError => e
    Rails.logger.error "Error syncing suppliers for product #{product_id}: #{e.message}"
  end

  def self.create_or_update(attributes)
    supply = find_or_initialize_by(
      sale_order_item_id: attributes[:sale_order_item].id,
      supplier_id: attributes[:supplier_id]
    )

    supply.assign_attributes(
      supplier_name: attributes[:supplier_name],
      supplier_type: attributes[:supplier_type],
      default: attributes[:default],
      last_sync_at: Time.current
    )
    print(supply.id)
    supply.save!
  end
end