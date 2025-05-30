class SalesOrdersController < ApplicationController
  include OrderReferenceHelper
  before_action :authenticate_user!
  before_action :set_order, only: [:show]

  def index
    begin
      # Carrega apenas os itens com estoque negativo, excluindo os ignorados e valores nulos
      @items = SaleOrderItem.includes(:sale_order_item_supply)
                            .where(ignore_order: [false, nil])
                            .where.not(produto_estoque: nil)
                            .where('CAST(produto_estoque AS INTEGER) < 0')
                            .order(created_at: :desc)

      # Inicializa contadores
      @checked_items_count = @items.where(checked_order: true).count
      @ignored_items_count = SaleOrderItem.where(ignore_order: true).count
      @total_items_count = @items.count
      @negative_stock_count = @items.count

      # Agrupa os itens por fornecedor
      @items_by_supplier = @items.each_with_object({}) do |item, hash|
        supplier_name = item.sale_order_item_supply&.supplier_name || 'Fornecedor não apontado'
        hash[supplier_name] ||= []
        hash[supplier_name] << item
      end

      # Remove fornecedores sem itens válidos
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

  # Método para exportar dados
  def export_negative_stock
    require 'csv'

    @items = SaleOrderItem.includes(:sale_order_item_supply)
                          .where(ignore_order: [false, nil])
                          .where.not(produto_estoque: nil)
                          .where('CAST(produto_estoque AS INTEGER) < 0')
                          .order(created_at: :desc)

    filename = "itens_estoque_negativo_#{Date.today.strftime('%d%m%Y')}.csv"

    csv_data = CSV.generate(headers: true) do |csv|
      # Cabeçalho
      csv << ['Código', 'Descrição', 'Fornecedor', 'Estoque', 'Quantidade', 'Valor Unitário', 'Valor Total', 'Data']
      
      # Dados
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