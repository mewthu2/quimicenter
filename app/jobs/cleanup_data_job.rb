class CleanupDataJob < ApplicationJob
  queue_as :default

  def perform(user_id = nil)
    Rails.logger.info 'Iniciando limpeza de dados do sistema...'

    begin
      cleanup_stats = {
        sale_orders_deleted: 0,
        sale_order_items_deleted: 0,
        sale_order_item_supplies_deleted: 0,
        attempts_deleted: 0,
        started_at: Time.current
      }

      cleanup_stats[:sale_order_item_supplies_deleted] = SaleOrderItemSupply.delete_all
      Rails.logger.info "Removidos #{cleanup_stats[:sale_order_item_supplies_deleted]} registros de sale_order_item_supplies"

      cleanup_stats[:sale_order_items_deleted] = SaleOrderItem.delete_all
      Rails.logger.info "Removidos #{cleanup_stats[:sale_order_items_deleted]} registros de sale_order_items"

      cleanup_stats[:sale_orders_deleted] = SaleOrder.delete_all
      Rails.logger.info "Removidos #{cleanup_stats[:sale_orders_deleted]} registros de sale_orders"

      cleanup_stats[:attempts_deleted] = Attempt.delete_all
      Rails.logger.info "Removidos #{cleanup_stats[:attempts_deleted]} registros de attempts"

      reset_sequences

      cleanup_stats[:completed_at] = Time.current
      cleanup_stats[:duration] = cleanup_stats[:completed_at] - cleanup_stats[:started_at]

      Rails.logger.info 'Limpeza concluída com sucesso!'
      Rails.logger.info 'Estatísticas: #{cleanup_stats}'

      sync_config = SyncConfiguration.current
      sync_config.update(
        notes: "Última limpeza: #{cleanup_stats[:completed_at].strftime('%d/%m/%Y %H:%M')} - " \
               "#{cleanup_stats[:sale_orders_deleted]} pedidos, " \
               "#{cleanup_stats[:sale_order_items_deleted]} itens removidos"
      )

      cleanup_stats

    rescue StandardError => e
      Rails.logger.error "Erro durante limpeza de dados: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end

  private

  def reset_sequences
    Rails.logger.info 'Resetando sequences do PostgreSQL...'

    sequences_to_reset = [
      'sale_orders_id_seq',
      'sale_order_items_id_seq',
      'sale_order_item_supplies_id_seq',
      'attempts_id_seq'
    ]

    sequences_to_reset.each do |sequence|
      ActiveRecord::Base.connection.execute("ALTER SEQUENCE #{sequence} RESTART WITH 1")
      Rails.logger.info "Sequence #{sequence} resetada"

      rescue StandardError => e
      Rails.logger.warn "Não foi possível resetar sequence #{sequence}: #{e.message}"
    end
  end
end
