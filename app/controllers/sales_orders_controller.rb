class SalesOrdersController < ApplicationController
  include OrderReferenceHelper
  before_action :authenticate_user!
  before_action :set_order, only: [:show]

  def index
    permitted_params = params.permit(:data_inicial, :data_final, :situacao, :id_contato, :id_vendedor, :numero, :id_nota_fiscal)
    @filters = permitted_params.to_h.symbolize_keys

    begin
      # Sincroniza os pedidos antes de exibir
      SaleOrder.sync_from_bling(filters: @filters)

      # Busca todos os pedidos sem paginação
      @orders = SaleOrder.includes(sale_order_items: :sale_order_item_supply)
                        .order(data: :desc)

      # Aplica filtros locais
      @orders = @orders.where(data: @filters[:data_inicial]..@filters[:data_final]) if @filters[:data_inicial].present? && @filters[:data_final].present?
      @orders = @orders.where(situacao_id: @filters[:situacao]) if @filters[:situacao].present?
      @orders = @orders.where(contato_id: @filters[:id_contato]) if @filters[:id_contato].present?
      @orders = @orders.where(numero: @filters[:numero]) if @filters[:numero].present?

      order_ids = @orders.pluck(:bling_id).map(&:to_s)

      @exported_attempts = Attempt.where(
        kinds: :create_purchase_order,
        status: :success
      ).where(
        'external_reference ~ ?', 
        "\\m(#{order_ids.join('|')})\\M"
      ).each_with_object({}) do |attempt, hash|
        matching_ids = attempt.external_reference.split(/\s*,\s*/) & order_ids
        matching_ids.each { |id| hash[id] = attempt }
      end

      # Agrupa pedidos por fornecedor
      @orders_by_supplier = @orders.each_with_object({}) do |order, hash|
        suppliers = order.sale_order_items.map do |item|
          item.sale_order_item_supply&.supplier_name || 'Fornecedor não apontado'
        end.uniq

        suppliers.each do |supplier|
          hash[supplier] ||= []
          hash[supplier] << order
        end
      end

    rescue => e
      @orders = []
      @orders_by_supplier = {}
      flash.now[:alert] = "Erro ao carregar pedidos: #{e.message}"
    end
  end


  def show
    @order_items = @order.sale_order_items
  rescue => e
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