# app/jobs/sync_sale_orders_job.rb
class SyncSaleOrdersJob < ApplicationJob
  queue_as :default

  SYNC_PERIOD = 1.days
  MAX_RETRIES = 3
  RETRY_DELAY = 2.seconds

  def perform
    since_date = SYNC_PERIOD.ago.to_date
    filters = { dataEmissaoInicial: since_date.strftime('%Y-%m-%d') }

    page = 1
    loop do
      response = fetch_orders_page(page, filters)
      orders_data = response['data'] || []
      break if orders_data.empty?

      orders_data.each do |order_data|
        sync_single_order_with_items(order_data['id'])
      end

      break if last_page?(response, page)
      page += 1
    end
  end

  private

  def sync_single_order_with_items(order_id)
    retries = 0
    begin
      order_response = Bling::SalesOrders.find(order_id)
      order_data = order_response['data']

      if order_data.present?
        sale_order = SaleOrder.create_or_update_from_bling(order_data)
        sync_suppliers_for_order_items(sale_order) if sale_order.persisted?
      else
        Rails.logger.warn "Pedido #{order_id} retornou sem dados"
      end
    rescue => e
      retries += 1
      if retries <= MAX_RETRIES
        sleep RETRY_DELAY
        retry
      else
        Rails.logger.error "Falha ao sincronizar pedido #{order_id} após #{MAX_RETRIES} tentativas: #{e.message}"
      end
    end
  end

  def sync_suppliers_for_order_items(sale_order)
    sale_order.sale_order_items.each do |item|
      next unless item.produto_id.present?
  
      begin
        SaleOrderItemSupply.sync_from_bling(item, item.produto_id)
      rescue => e
        Rails.logger.error "Error syncing suppliers for item #{item.id}: #{e.message}"
      end
    end
  end

  def fetch_orders_page(page, filters)
    retries = 0
    begin
      Bling::Orders.all(page, filters)
    rescue => e
      retries += 1
      if retries <= MAX_RETRIES
        sleep RETRY_DELAY
        retry
      else
        raise "Falha ao buscar página #{page} de pedidos: #{e.message}"
      end
    end
  end

  def last_page?(response, current_page)
    total_pages = response.dig('total', 'totalPages') || 1
    current_page >= total_pages.to_i
  end
end