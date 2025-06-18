class SalesOrdersController < ApplicationController
  include OrderReferenceHelper
  before_action :authenticate_user!
  before_action :set_order, only: [:show]

  def index
    begin
      @items = SaleOrderItem.includes(:sale_order_item_supply)
                            .where(ignore_order: [false, nil])
                            .where.not(produto_estoque: nil)
                            .where('CAST(produto_estoque AS INTEGER) < 0')
                            .order(created_at: :desc)

      @checked_items_count = @items.where(checked_order: true).count
      @ignored_items_count = SaleOrderItem.where(ignore_order: true).count
      @total_items_count = @items.count
      @negative_stock_count = @items.count

      @items_by_supplier = @items.each_with_object({}) do |item, hash|
        supplier_name = item.sale_order_item_supply&.supplier_name || 'Fornecedor não apontado'
        hash[supplier_name] ||= []
        hash[supplier_name] << item
      end

      @items_by_supplier.reject! { |_, items| items.empty? }

    rescue StandardError => e
      @items_by_supplier = {}
      @checked_items_count = 0
      @ignored_items_count = 0
      @total_items_count = 0
      @negative_stock_count = 0
      flash.now[:alert] = "Erro ao carregar itens: #{e.message}"
    end
  end

  def show
    @order_items = @order.sale_order_items
  rescue StandardError => e
    flash[:alert] = 'Pedido não encontrado'
    redirect_to sales_orders_path
  end

  def save_item
    begin
      @item = SaleOrderItem.find(params[:id])

      item_params = params.permit(:checked_order, :quantity_order)

      checked_order = item_params[:checked_order] == '1' || item_params[:checked_order] == 'true'
      quantity_order = item_params[:quantity_order].to_f
      
      if checked_order && quantity_order <= 0
        render json: { 
          success: false, 
          message: 'Quantidade deve ser maior que zero quando o item está selecionado' 
        }, status: :unprocessable_entity
        return
      end

      @item.update!(
        checked_order: checked_order,
        quantity_order: checked_order ? quantity_order : nil
      )

      render json: {
        success: true,
        message: 'Item salvo com sucesso!',
        item: {
          id: @item.id,
          checked_order: @item.checked_order,
          quantity_order: @item.quantity_order
        }
      }

    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        message: 'Item não encontrado'
      }, status: :not_found

    rescue ActiveRecord::RecordInvalid => e
      render json: {
        success: false,
        message: "Erro ao salvar: #{e.message}"
      }, status: :unprocessable_entity

    rescue StandardError => e
      render json: {
        success: false,
        message: "Erro interno: #{e.message}"
      }, status: :internal_server_error
    end
  end

  def save_multiple_items
    begin
      items_data = params[:items] || []
      updated_items = []
      errors = []
      
      items_data.each do |item_data|
        item = SaleOrderItem.find(item_data[:id])
        checked_order = item_data[:checked_order] == '1' || item_data[:checked_order] == 'true'
        quantity_order = item_data[:quantity_order].to_f
        
        if checked_order && quantity_order <= 0
          errors << "Item #{item.produto_codigo}: Quantidade deve ser maior que zero"
          next
        end
        
        item.update!(
          checked_order: checked_order,
          quantity_order: checked_order ? quantity_order : nil
        )
        
        updated_items << {
          id: item.id,
          checked_order: item.checked_order,
          quantity_order: item.quantity_order
        }
      end
      
      if errors.any?
        render json: { 
          success: false, 
          message: 'Alguns itens não puderam ser salvos',
          errors: errors,
          updated_items: updated_items
        }, status: :unprocessable_entity
      else
        render json: { 
          success: true, 
          message: "#{updated_items.count} itens salvos com sucesso!",
          updated_items: updated_items
        }
      end
      
    rescue StandardError => e
      render json: { 
        success: false, 
        message: "Erro ao salvar itens: #{e.message}" 
      }, status: :internal_server_error
    end
  end

  def export_negative_stock
    require 'csv'

    @items = SaleOrderItem.includes(:sale_order_item_supply)
                          .where(ignore_order: [false, nil])
                          .where.not(produto_estoque: nil)
                          .where('CAST(produto_estoque AS INTEGER) < 0')
                          .order(created_at: :desc)

    filename = "itens_estoque_negativo_#{Date.today.strftime('%d%m%Y')}.csv"

    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['Código', 'Descrição', 'Fornecedor', 'Estoque', 'Quantidade', 'Valor Unitário', 'Valor Total', 'Data']

      @items.each do |item|
        csv << [
          item.produto_codigo,
          item.produto_descricao,
          item.sale_order_item_supply&.supplier_name || 'Não definido',
          item.produto_estoque,
          item.quantidade,
          item.valor_unitario,
          item.valor_total,
          item.created_at&.strftime('%d/%m/%Y')
        ]
      end
    end
    
    send_data csv_data, filename: filename, type: 'text/csv'
  end

  private

  def set_order
    @order = SaleOrder.find_by(bling_id: params[:id])
    raise 'Pedido não encontrado' unless @order.present?
  end

  def generate_order_reference(order)
    [
      order.data.to_s.strip,
      order.contato_id.to_s
    ].join('#')
  end
end
