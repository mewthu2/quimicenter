class SaleOrderItemsController < ApplicationController
  before_action :authenticate_user!

  def index
    @view_mode = params[:view_mode] || 'ready' # 'ready' ou 'migrated'
    @search = params[:search]
    @supplier = params[:supplier]
    @sort_by = params[:sort_by] || 'date_desc'

    @items = build_items_query
    @items = apply_search(@items) if @search.present?
    @items = apply_supplier_filter(@items) if @supplier.present?
    @items = apply_sorting(@items)
    @items = @items.limit(100)

    # Agrupar itens por fornecedor
    @items_by_supplier = @items.each_with_object({}) do |item, hash|
      supplier_name = item.sale_order_item_supply&.supplier_name || 'Fornecedor não apontado'
      hash[supplier_name] ||= []
      hash[supplier_name] << item
    end

    # Remover grupos vazios
    @items_by_supplier.reject! { |_, items| items.empty? }

    # Calcular estatísticas baseadas no modo de visualização
    @total_items_count = @items.count
    if @view_mode == 'ready'
      @ready_for_processing_count = @total_items_count
      @processed_count = 0
    else
      @ready_for_processing_count = 0
      @processed_count = @total_items_count
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

  def process_item
    begin
      item = SaleOrderItem.find(params[:id])

      if item.sale_order_item_supply.blank?
        render json: {
          success: false,
          message: 'Item precisa ter um fornecedor definido antes de ser processado' 
        }, status: :unprocessable_entity
        return
      end

      item.update!(
        purchase_order_created_at: Time.current
      )

      render json: {
        success: true,
        message: 'Item processado com sucesso!'
      }
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        message: 'Item não encontrado'
      }, status: :not_found
    rescue StandardError => e
      render json: {
        success: false,
        message: "Erro ao processar item: #{e.message}"
      }, status: :internal_server_error
    end
  end

  def process_multiple
    begin
      item_ids = params[:item_ids] || []

      if item_ids.empty?
        render json: { 
          success: false, 
          message: 'Nenhum item selecionado' 
        }, status: :unprocessable_entity
        return
      end

      items = SaleOrderItem.where(id: item_ids)
      items_without_supplier = items.left_joins(:sale_order_item_supply)
                                   .where(sale_order_item_supplies: { id: nil })

      if items_without_supplier.any?
        render json: { 
          success: false, 
          message: 'Alguns itens não possuem fornecedor definido' 
        }, status: :unprocessable_entity
        return
      end

      items.update_all(
        purchase_order_created_at: Time.current
      )

      render json: { 
        success: true, 
        message: "#{items.count} itens processados com sucesso!" 
      }
    rescue StandardError => e
      render json: { 
        success: false, 
        message: "Erro ao processar itens: #{e.message}" 
      }, status: :internal_server_error
    end
  end

  def ignore_item
    begin
      item = SaleOrderItem.find(params[:id])
      item.update!(ignore_order: true)
      render json: { 
        success: true, 
        message: 'Item ignorado com sucesso!' 
      }
    rescue ActiveRecord::RecordNotFound
      render json: { 
        success: false, 
        message: 'Item não encontrado' 
      }, status: :not_found
    rescue StandardError => e
      render json: { 
        success: false, 
        message: "Erro ao ignorar item: #{e.message}" 
      }, status: :internal_server_error
    end
  end

  def ignore_multiple
    begin
      item_ids = params[:item_ids] || []

      if item_ids.empty?
        render json: { 
          success: false, 
          message: 'Nenhum item selecionado' 
        }, status: :unprocessable_entity
        return
      end

      items = SaleOrderItem.where(id: item_ids)
      items.update_all(ignore_order: true)

      render json: { 
        success: true, 
        message: "#{items.count} itens ignorados com sucesso!" 
      }
    rescue StandardError => e
      render json: { 
        success: false, 
        message: "Erro ao ignorar itens: #{e.message}" 
      }, status: :internal_server_error
    end
  end

  def item_details
    begin
      item = SaleOrderItem.includes(:sale_order, :sale_order_item_supply).find(params[:id])

      render json: {
        success: true,
        item: {
          id: item.id,
          order_number: item.sale_order.numero,
          order_date: item.sale_order.data.strftime('%d/%m/%Y'),
          customer_name: item.sale_order.contato_nome || 'Cliente não identificado',
          supplier_name: item.sale_order_item_supply&.supplier_name || 'Não definido',
          product_name: item.produto_descricao,
          product_code: item.produto_codigo,
          quantity: item.quantity_order,
          unit_value: item.valor_unitario,
          total_value: item.valor_total,
          integration_date: item.purchase_order_created_at&.strftime('%d/%m/%Y %H:%M'),
          bling_order_id: item.bling_order_id,
          status: item.bling_order_id.present? ? 'completed' : 'pending'
        }
      }
    rescue ActiveRecord::RecordNotFound
      render json: { 
        success: false, 
        message: 'Item não encontrado' 
      }, status: :not_found
    end
  end

  private

  def build_items_query
    base_query = SaleOrderItem.joins(:sale_order)
                              .left_joins(:sale_order_item_supply)
                              .where(ignore_order: [false, nil])
                              .where(checked_order: true)
                              .where.not('sale_orders.bling_id': nil)

    case params[:view_mode]
    when 'migrated'
      # Mostrar itens que já foram migrados (têm bling_order_id)
      base_query.where.not(bling_order_id: [nil, ''])
    else
      # Mostrar itens prontos para processamento (sem bling_order_id)
      base_query.where(bling_order_id: [nil, ''])
    end
  end

  def apply_search(query)
    search_term = "%#{@search.downcase}%"
    query.where(
      'LOWER(sale_order_items.produto_descricao) LIKE ? OR 
       LOWER(sale_order_items.produto_codigo) LIKE ? OR 
       LOWER(sale_orders.numero) LIKE ?',
      search_term, search_term, search_term
    )
  end

  def apply_supplier_filter(query)
    query.joins(:sale_order_item_supply)
         .where(sale_order_item_supplies: { id: @supplier })
  end

  def apply_sorting(query)
    case @sort_by
    when 'date_desc'
      query.order('sale_orders.data DESC')
    when 'date_asc'
      query.order('sale_orders.data ASC')
    when 'quantity_desc'
      query.order('CAST(sale_order_items.quantity_order AS DECIMAL) DESC')
    when 'quantity_asc'
      query.order('CAST(sale_order_items.quantity_order AS DECIMAL) ASC')
    when 'processed_desc'
      query.order('sale_order_items.purchase_order_created_at DESC')
    when 'processed_asc'
      query.order('sale_order_items.purchase_order_created_at ASC')
    else
      if params[:view_mode] == 'migrated'
        query.order('sale_order_items.purchase_order_created_at DESC')
      else
        query.order('sale_orders.data DESC')
      end
    end
  end

  def item_params
    params.require(:sale_order_item).permit(:checked_order, :ignore_order, :quantity_order)
  end
end
