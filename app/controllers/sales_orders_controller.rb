class SalesOrdersController < ApplicationController
  include OrderReferenceHelper
  before_action :authenticate_user!
  before_action :set_order, only: [:show]

  def index
    @page = params[:page] || 1
    permitted_params = params.permit(:data_inicial, :data_final, :situacao, :id_contato, :id_vendedor, :numero, :id_nota_fiscal, :page)
    @filters = permitted_params.to_h.symbolize_keys

    begin
      response = Bling::Orders.all(@page, @filters)
      @orders = response['data'] || []

      order_ids = @orders.map { |o| o['id'].to_s }

      @exported_attempts = Attempt.where(
        kinds: :create_purchase_order,
        status: :success
      ).where(
        'external_reference ~ ?', 
        "\\m(#{order_ids.join('|')})\\M"
      ).each_with_object({}) do |attempt, hash|

        matching_ids = attempt.external_reference.split(/\s*,\s*/) & order_ids

        matching_ids.each do |id|
          hash[id] = attempt # Usamos o mesmo attempt para múltiplos IDs
        end
      end

    rescue => e
      @orders = []
      flash.now[:alert] = "Erro ao carregar pedidos: #{e.message}"
    end
  end
 
  def show
  rescue => e
    flash[:alert] = 'Pedido não encontrado'
    redirect_to sales_orders_path
  end

  private

  def set_order
    @order = Bling::Orders.find(params[:id])
    raise 'Pedido não encontrado' unless @order.present?
  end

  def generate_order_reference(order)
    [
      order['data'].to_s.strip,
      order.dig('contato', 'id').to_s
    ].join('#')
  end
end