# app/controllers/purchase_orders_controller.rb
class PurchaseOrdersController < ApplicationController
  before_action :authenticate_user!
  helper_method :current_stock_for, :preferred_supplier_for, :format_date

  def index
    @filter = params[:filter] || 'all'
    @page = params[:page] || 1

    begin
      if @filter == 'all'
        response = Bling::PurchaseOrders.all(@page)
      else
        response = Bling::PurchaseOrders.by_situation(@filter, @page)
      end

      if response.is_a?(Hash) && response['data'].is_a?(Array)
        @purchase_orders = response['data']

        @total_pages = response.dig('total', 'totalPages').to_i.positive? ? response.dig('total', 'totalPages').to_i : 1
      else
        flash.now[:alert] = 'Estrutura de dados inesperada da API'
        @purchase_orders = []
        @total_pages = 1
      end
    rescue => e
      flash.now[:alert] = "Erro ao buscar pedidos de compra: #{e.message}"
      @purchase_orders = []
      @total_pages = 1
      Rails.logger.error "Erro PurchaseOrders#index: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end

  def new
    @selected_order_ids = params[:selected_orders] || []
    @sales_orders = []

    @suppliers_fallback = Bling::Contacts.suppliers['data'] || []

    if @selected_order_ids.any?
      @sales_orders = @selected_order_ids.map do |id|
        order = Bling::SalesOrders.find(id)['data']

        order['itens'].each do |item|
          product_data = item['produto'] || {}
          item['current_stock'] = current_stock_for(product_data)

          suppliers = product_suppliers_for(product_data['id'])
          item['product_suppliers'] = suppliers.any? ? suppliers : @suppliers_fallback
        end

        order
      end
    else
      redirect_to sales_orders_path, alert: 'Nenhum pedido selecionado'
    end
  end

  def load_items
    @order = Bling::SalesOrders.find(params[:order_id])['data']
    respond_to do |format|
      format.js
    end
  end

  def create
    items_params = params.require(:items).to_unsafe_h
    sales_order_ids = params[:sales_order_ids] || []

    begin
      # Agrupar itens por fornecedor
      items_by_supplier = {}

      items_params.each do |item_id, item_attrs|
        next unless item_attrs[:quantity].present? && item_attrs[:quantity].to_i > 0

        supplier_id = item_attrs[:supplier_id].presence || item_attrs[:supplier_name]
        next unless supplier_id.present?

        items_by_supplier[supplier_id] ||= []
        items_by_supplier[supplier_id] << {
          'descricao' => item_attrs[:descricao].presence || "Produto #{item_id}",
          'codigo' => item_attrs[:codigo].presence || item_id.to_s,
          'unidade' => item_attrs[:unidade].presence || 'UN',
          'valor' => item_attrs[:valor].to_f.positive? ? item_attrs[:valor].to_f : 0.01, # Valor unitário (sem cálculo de total)
          'quantidade' => item_attrs[:quantity].to_i,
          'aliquotaIPI' => item_attrs[:aliquotaIPI].to_f,
          'descricaoDetalhada' => item_attrs[:descricaoDetalhada].presence || item_attrs[:descricao],
          'produto' => {
            'id' => item_attrs.dig(:produto, :id).to_i,
            'codigo' => item_attrs[:codigo].presence || item_id.to_s
          }
        }
      end

      if items_by_supplier.empty?
        raise 'Nenhum item válido para criar o pedido de compra'
      end

      results = []
      items_by_supplier.each do |supplier_id, items|
        purchase_order_data = {
          'data' => params[:data].presence || Date.today.strftime('%Y-%m-%d'),
          'dataPrevista' => params[:dataPrevista].presence || (Date.today + 7.days).strftime('%Y-%m-%d'),
          'fornecedor' => {
            'id' => supplier_id.to_s
          },
          'situacao' => {
            'valor' => params.dig(:situacao, :valor) || 0
          },
          'itens' => items,
          'observacoes' => params[:observacoes].presence || 'Pedido gerado automaticamente pelo sistema',
          'selected_orders' => params[:selected_orders]
        }

        Rails.logger.info "Dados sendo enviados para a API: #{purchase_order_data.inspect}"
        response = CreatePurchaseOrderJob.perform_now(purchase_order_data)
        results << response
      end

      if results.all? { |r| r['id'].present? }
        redirect_to purchase_orders_path, notice: 'Pedidos de compra criados com sucesso!'
      else
        raise "Erro ao criar alguns pedidos - respostas: #{results.inspect}"
      end

    rescue => e
      Rails.logger.error "Erro ao criar pedido de compra: #{e.message}\n#{e.backtrace.join("\n")}"
      redirect_to new_purchase_order_path(selected_orders: sales_order_ids),
                  alert: "Erro ao criar pedido: #{e.message}"
    end
  end

  private

  def current_stock_for(product_data)
    return 0 unless product_data.present?

    product_id = product_data['id']
    return 0 unless product_id.present?

    begin
      response = Bling::Products.find(product_id)
      stock = response.dig('data', 'estoque', 'saldoVirtualTotal') || 
              response.dig('data', 'estoqueAtual') || 
              0
      stock.to_i
    rescue => e
      Rails.logger.error "Erro ao buscar estoque para #{product_id}: #{e.message}"
      0
    end
  end

  def product_suppliers_for(product_id)
    return [] unless product_id.present?

    begin
      response = Bling::ProductSuppliers.list(product_id:)
      supplier_data = response['data'] || []

      supplier_data.map do |supplier|
        next unless supplier['fornecedor'] && supplier['fornecedor']['id'].present?

        contact = Bling::Contacts.find(supplier['fornecedor']['id'])['data']
        contact_data = contact || {}
        {
          id: contact_data['id'],
          nome: contact_data['nome'],
          tipo: contact_data['tipo'],
          padrao: supplier['padrao'] || false
        }
      end.compact
    rescue => e
      Rails.logger.error "Erro ao buscar fornecedores para produto #{product_id}: #{e.message}"
      []
    end
  end

  def preferred_supplier_for(product_id)
    suppliers = product_suppliers_for(product_id)
    suppliers.find { |s| s[:padrao] } || suppliers.first
  end

  def format_date(date_string)
    return 'N/A' if date_string.blank?
    Date.parse(date_string).strftime('%d/%m/%Y') rescue 'Data inválida'
  end

  def number_to_currency(value)
    ActionController::Base.helpers.number_to_currency(value, unit: "R$ ", separator: ",", delimiter: ".")
  end
end
