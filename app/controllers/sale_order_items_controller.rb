class SaleOrderItemsController < ApplicationController
  def index
    @status = params[:status] || 'pending' # 'pending' ou 'completed'
  
    case @status
    when 'pending'
      @items = SaleOrderItem.joins(:sale_order)
                           .left_joins(:sale_order_item_supply)
                           .where(checked_order: true, ignore_order: false)
                           .where('CAST(quantity_order AS INTEGER) > 0')
                           .where.not(bling_order_id: nil) # Campo está em SaleOrderItem
                           .where(sale_order_item_supplies: { id: nil })
                           .order('sale_orders.data DESC') # Campo data está em SaleOrder
  
    when 'completed'
      @items = SaleOrderItem.joins(:sale_order)
                            .left_joins(:sale_order_item_supply)
                            .where.not(purchase_order_created_at: nil) # Campo está em SaleOrderItem
                            .order('sale_order_items.purchase_order_created_at DESC') # Ordenando pelo campo em SaleOrderItem
    else
      @items = SaleOrderItem.none
    end
  end

  def assign_supplier
    item = SaleOrderItem.find(params[:id])

    begin
      contact_data = Bling::Contacts.find(params[:supplier_id])['data'] || {}

      SaleOrderItemSupply.create_or_update(
        sale_order_item: item,
        supplier_id: contact_data['id'],
        supplier_name: contact_data['nome'],
        supplier_type: contact_data['tipo'],
        default: false
      )

      render json: {
        success: true,
        supplier_name: contact_data['nome'] || "Fornecedor #{params[:supplier_id]}"
      }
    rescue StandardError => e
      Rails.logger.error "Error assigning supplier: #{e.message}"
      render json: { success: false, message: e.message }, status: :unprocessable_entity
    end
  end

  def update_item
    item = SaleOrderItem.find(params[:id])

    if item.update(item_params)
      render json: { success: true }
    else
      render json: { success: false, message: item.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  private

  def item_params
    params.require(:sale_order_item).permit(:checked_order, :ignore_order, :quantity_order)
  end
end