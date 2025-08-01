class HomeController < ApplicationController
  before_action :authenticate_user!
  
  def index
    begin
      # Dados básicos de itens com estoque negativo
      @negative_stock_items = fetch_negative_stock_items
      @negative_stock_count = @negative_stock_items.count
      @checked_items_count = @negative_stock_items.where(checked_order: true).count
      @pending_items_count = @negative_stock_count - @checked_items_count
      
      # Dados de itens ignorados
      @ignored_items_count = fetch_ignored_items_count
      
      # Dados de processamento
      @processed_items_count = fetch_processed_items_count
      @items_with_supplier = fetch_items_with_supplier_count
      @items_without_supplier = fetch_items_without_supplier_count
      
      # Configuração de sincronização
      @sync_config = fetch_sync_configuration
      @enabled_days_count = @sync_config&.enabled_days&.count || 0
      @total_scheduled_hours = @sync_config&.all_scheduled_hours&.count || 0
      
      # Dados por fornecedor
      @suppliers_data = fetch_suppliers_data
      
      # Dados dos últimos 7 dias
      @daily_stats = calculate_daily_stats
      
      # Valor total em estoque negativo
      @total_negative_value = calculate_total_negative_value
      
      # Status do sistema
      @system_status = build_system_status
      
    rescue StandardError => e
      Rails.logger.error "Erro no dashboard: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      flash.now[:alert] = "Erro ao carregar dados do dashboard: #{e.message}"
      set_default_values
    end
  end
  
  private
  
  def fetch_negative_stock_items
    SaleOrderItem.where.not(produto_estoque: nil)
                 .where('CAST(produto_estoque AS INTEGER) < 0')
                 .where(bling_order_id: [nil, ''])
                 .where(ignore_order: [false, nil])
  rescue StandardError => e
    Rails.logger.error "Erro ao buscar itens com estoque negativo: #{e.message}"
    SaleOrderItem.none
  end
  
  def fetch_ignored_items_count
    SaleOrderItem.where(ignore_order: true).count
  rescue StandardError => e
    Rails.logger.error "Erro ao contar itens ignorados: #{e.message}"
    0
  end
  
  def fetch_processed_items_count
    SaleOrderItem.where.not(bling_order_id: [nil, '']).count
  rescue StandardError => e
    Rails.logger.error "Erro ao contar itens processados: #{e.message}"
    0
  end
  
  def fetch_items_with_supplier_count
    return 0 unless table_exists?('sale_order_item_supplies')
    SaleOrderItem.joins(:sale_order_item_supply).count
  rescue StandardError => e
    Rails.logger.error "Erro ao contar itens com fornecedor: #{e.message}"
    0
  end
  
  def fetch_items_without_supplier_count
    return 0 unless table_exists?('sale_order_item_supplies')
    SaleOrderItem.left_joins(:sale_order_item_supply)
                 .where(sale_order_item_supplies: { id: nil })
                 .count
  rescue StandardError => e
    Rails.logger.error "Erro ao contar itens sem fornecedor: #{e.message}"
    0
  end
  
  def fetch_sync_configuration
    return nil unless table_exists?('sync_configurations')
    SyncConfiguration.current
  rescue StandardError => e
    Rails.logger.error "Erro ao buscar configuração de sync: #{e.message}"
    nil
  end
  
  def fetch_suppliers_data
    return [] unless table_exists?('sale_order_item_supplies')
    
    @negative_stock_items.joins(:sale_order_item_supply)
                         .group('sale_order_item_supplies.supplier_name')
                         .count
                         .sort_by { |_, count| -count }
                         .first(5)
  rescue StandardError => e
    Rails.logger.error "Erro ao buscar dados de fornecedores: #{e.message}"
    []
  end
  
  def calculate_daily_stats
    stats = []
    7.days.ago.to_date.upto(Date.current) do |date|
      begin
        items_created = SaleOrderItem.where(created_at: date.beginning_of_day..date.end_of_day).count
        items_processed = SaleOrderItem.where(
          purchase_order_created_at: date.beginning_of_day..date.end_of_day
        ).count
        
        stats << {
          date: date.strftime('%Y-%m-%d'),
          created: items_created,
          processed: items_processed
        }
      rescue StandardError => e
        Rails.logger.error "Erro ao calcular estatísticas para #{date}: #{e.message}"
        stats << {
          date: date.strftime('%Y-%m-%d'),
          created: 0,
          processed: 0
        }
      end
    end
    stats
  rescue StandardError => e
    Rails.logger.error "Erro ao calcular estatísticas diárias: #{e.message}"
    []
  end
  
  def calculate_total_negative_value
    return 0 if @negative_stock_items.empty?
    
    @negative_stock_items.sum do |item|
      valor_unitario = item.valor_unitario.to_f || 0
      quantidade = item.quantidade.to_f || 0
      valor_unitario * quantidade
    end
  rescue StandardError => e
    Rails.logger.error "Erro ao calcular valor total negativo: #{e.message}"
    0
  end
  
  def build_system_status
    {
      sync_active: @sync_config&.active? || false,
      last_sync: @sync_config&.last_sync_at,
      queue_size: @checked_items_count,
      processing_rate: calculate_processing_rate
    }
  rescue StandardError => e
    Rails.logger.error "Erro ao construir status do sistema: #{e.message}"
    {
      sync_active: false,
      last_sync: nil,
      queue_size: 0,
      processing_rate: 0
    }
  end
  
  def calculate_processing_rate
    return 0 if @checked_items_count == 0
    
    processed_today = SaleOrderItem.where(
      purchase_order_created_at: Date.current.beginning_of_day..Date.current.end_of_day
    ).count
    
    ((processed_today.to_f / @checked_items_count) * 100).round(1)
  rescue StandardError => e
    Rails.logger.error "Erro ao calcular taxa de processamento: #{e.message}"
    0
  end
  
  def table_exists?(table_name)
    ActiveRecord::Base.connection.table_exists?(table_name)
  rescue StandardError => e
    Rails.logger.error "Erro ao verificar existência da tabela #{table_name}: #{e.message}"
    false
  end
  
  def set_default_values
    @negative_stock_count = 0
    @checked_items_count = 0
    @pending_items_count = 0
    @ignored_items_count = 0
    @processed_items_count = 0
    @items_with_supplier = 0
    @items_without_supplier = 0
    @sync_config = nil
    @enabled_days_count = 0
    @total_scheduled_hours = 0
    @suppliers_data = []
    @daily_stats = []
    @total_negative_value = 0
    @system_status = {
      sync_active: false,
      last_sync: nil,
      queue_size: 0,
      processing_rate: 0
    }
  end
end
