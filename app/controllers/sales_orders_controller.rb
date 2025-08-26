class SalesOrdersController < ApplicationController
  include OrderReferenceHelper
  before_action :authenticate_user!
  before_action :set_order, only: [:show]

  def index
    begin
      show_ignored = params[:show_ignored] == 'true'
      
      start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
      end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
    
      # Query base para todos os itens com estoque negativo
      base_query = SaleOrderItem.includes(:sale_order_item_supply)
                               .where.not(produto_estoque: nil)
                               .where('CAST(produto_estoque AS INTEGER) < 0')
                               .where(bling_order_id: [nil, ''])
                               .order(created_at: :desc)

      if start_date.present? && end_date.present?
        base_query = base_query.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      elsif start_date.present?
        base_query = base_query.where('created_at >= ?', start_date.beginning_of_day)
      elsif end_date.present?
        base_query = base_query.where('created_at <= ?', end_date.end_of_day)
      end

      if show_ignored
        # Mostra todos os itens (ativos + excluídos)
        @all_items = base_query
        @active_items = base_query.where(ignore_order: [false, nil])
        @ignored_items = base_query.where(ignore_order: true)
      else
        # Mostra apenas itens ativos
        @all_items = base_query.where(ignore_order: [false, nil])
        @active_items = @all_items
        @ignored_items = []
      end

      @sale_order_items = @all_items

      @items_by_supplier = @active_items.group_by do |item|
        item.sale_order_item_supply&.supplier_name || "Fornecedor não identificado"
      end

      @ignored_items_by_supplier = @ignored_items.group_by do |item|
        item.sale_order_item_supply&.supplier_name || "Fornecedor não identificado"
      end

      @show_ignored = show_ignored
      @start_date = start_date
      @end_date = end_date
      @checked_items_count = @active_items.where(checked_order: true).count
      @ignored_items_count = base_query.where(ignore_order: true).count
      @total_items_count = @active_items.count
      @negative_stock_count = @active_items.count

    rescue StandardError => e
      @sale_order_items = []
      @items_by_supplier = {}
      @ignored_items_by_supplier = {}
      @show_ignored = false
      @start_date = nil
      @end_date = nil
      @checked_items_count = 0
      @ignored_items_count = 0
      @total_items_count = 0
      @negative_stock_count = 0
      flash.now[:alert] = "Erro ao carregar itens: #{e.message}"
    end
  end


  def add_supplier_to_item
    begin
      @item = SaleOrderItem.find(params[:sale_order_item_id])
      
      supplier_params = params.permit(:supplier_id, :supplier_name, :supplier_type, :default)
      
      # Validações
      if supplier_params[:supplier_id].blank?
        render json: {
          success: false,
          message: 'ID do fornecedor é obrigatório'
        }, status: :unprocessable_entity
        return
      end

      if supplier_params[:supplier_name].blank?
        render json: {
          success: false,
          message: 'Nome do fornecedor é obrigatório'
        }, status: :unprocessable_entity
        return
      end

      SaleOrderItemSupply.create_or_update(
        sale_order_item: @item,
        supplier_id: supplier_params[:supplier_id].to_i,
        supplier_name: supplier_params[:supplier_name],
        supplier_type: supplier_params[:supplier_type] || 'Pessoa Jurídica',
        default: supplier_params[:default] == '1' || supplier_params[:default] == 'true'
      )
      
      render json: {
        success: true,
        message: 'Fornecedor adicionado com sucesso!',
        supplier_name: supplier_params[:supplier_name]
      }
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        message: 'Item não encontrado'
      }, status: :not_found
    rescue ActiveRecord::RecordInvalid => e
      render json: {
        success: false,
        message: "Erro ao adicionar fornecedor: #{e.message}"
      }, status: :unprocessable_entity
    rescue StandardError => e
      render json: {
        success: false,
        message: "Erro interno: #{e.message}"
      }, status: :internal_server_error
    end
  end

  def export_negative_stock
    require 'csv'

    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil

    @items = SaleOrderItem.includes(:sale_order_item_supply)
                          .where(ignore_order: [false, nil])
                          .where.not(produto_estoque: nil)
                          .where('CAST(produto_estoque AS INTEGER) < 0')
                          .where(bling_order_id: [nil, ''])
                          .order(created_at: :desc)

    if start_date.present? && end_date.present?
      @items = @items.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    elsif start_date.present?
      @items = @items.where('created_at >= ?', start_date.beginning_of_day)
    elsif end_date.present?
      @items = @items.where('created_at <= ?', end_date.end_of_day)
    end
    
    date_suffix = if start_date.present? && end_date.present?
                    "_#{start_date.strftime('%d%m%Y')}_a_#{end_date.strftime('%d%m%Y')}"
                  elsif start_date.present?
                    "_a_partir_#{start_date.strftime('%d%m%Y')}"
                  elsif end_date.present?
                    "_ate_#{end_date.strftime('%d%m%Y')}"
                  else
                    "_#{Date.today.strftime('%d%m%Y')}"
                  end
    
    filename = "itens_estoque_negativo#{date_suffix}.csv"
    
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['Código', 'Descrição', 'Fornecedor', 'Código Bling Fornecedor', 'Estoque', 'Quantidade', 'Valor Unitário', 'Valor Total', 'Data']

      @items.each do |item|
        csv << [
          item.produto_codigo,
          item.produto_descricao,
          item.sale_order_item_supply&.supplier_name || 'Não definido',
          item.sale_order_item_supply&.supplier_bling_code || 'Não definido',
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
    # Implementar se necessário
  end
end
