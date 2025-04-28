class SalesOrdersController < ApplicationController
  include OrderReferenceHelper
  before_action :authenticate_user!
  before_action :set_order, only: [:show]

  def index
    begin
      # Carrega apenas os itens com seus fornecedores
      @items = SaleOrderItem.includes(:sale_order_item_supply)
                            .order(created_at: :desc)

      # Inicializa contadores
      @checked_items_count = @items.where(checked_order: true).count
      @ignored_items_count = @items.where(ignore_order: true).count
      @total_items_count = @items.count

      # Agrupa os itens por fornecedor, excluindo os marcados
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
      flash.now[:alert] = "Erro ao carregar itens: #{e.message}"
    end
  end

  def show
    @order_items = @order.sale_order_items
  rescue StandardError => e
    flash[:alert] = 'Pedido não encontrado'
    redirect_to sales_orders_path
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