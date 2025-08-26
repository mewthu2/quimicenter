class CreatePurchaseOrderJob < ApplicationJob
  def perform
    return unless should_execute_now?

    items = SaleOrderItem.where(checked_order: true)
                         .where.not(quantity_order: [nil, 0])
                         .where(bling_order_id: nil)
                         .includes(:sale_order_item_supply, :sale_order)

    items_by_supplier = items.group_by do |item|
      item.sale_order_item_supply&.supplier_id
    end

    items_by_supplier.delete(nil)

    items_by_supplier.each do |supplier_id, supplier_items|
      create_order_for_supplier(supplier_id, supplier_items)
    end
  end

  def should_execute_now?
    config = SyncConfiguration.active.first
    return false unless config&.active?

    current_time = Time.current
    current_day = current_time.strftime('%A').downcase
    current_hour_minute = current_time.strftime('%H:%M')

    day_config = config.schedule_data[current_day]
    return false unless day_config&.dig('enabled') == 'true'

    scheduled_hours = day_config['hours'] || []
    return true if scheduled_hours.empty?

    scheduled_hours.any? { |hour| current_hour_minute >= hour }
  end

  def self.next_scheduled_execution
    config = SyncConfiguration.active.first
    return nil unless config&.active?

    current_time = Time.current

    7.times do |days_ahead|
      check_date = current_time + days_ahead.days
      day_name = check_date.strftime('%A').downcase
      day_config = config.schedule_data[day_name]

      next unless day_config&.dig('enabled') == 'true'

      scheduled_hours = day_config['hours'] || []
      next if scheduled_hours.empty?

      scheduled_hours.each do |hour|
        scheduled_time = Time.parse("#{check_date.strftime('%Y-%m-%d')} #{hour}")
        return scheduled_time if scheduled_time > current_time
      end
    end
    
    nil
  end

  private

  def create_order_for_supplier(supplier_id, items)
    first_item = items.first
    supplier = first_item.sale_order_item_supply

    order_items = items.map do |item|
      {
        descricao: item.produto_descricao,
        codigoFornecedor: item.produto_codigo,
        unidade: item.unidade || 'UN',
        valor: item.valor_unitario.to_f.positive? ? item.valor_unitario.to_f : 0.01,
        quantidade: item.quantity_order.to_f,
        aliquotaIPI: item.aliquota_ipi.to_f,
        descricaoDetalhada: item.descricao_detalhada.presence || item.produto_descricao,
        produto: {
          id: item.produto_id.to_s,
          codigo: item.produto_codigo
        }.compact
      }.compact
    end

    payload = {
      data: Date.current.strftime('%Y-%m-%d'),
      dataPrevista: Date.current.strftime('%Y-%m-%d'),
      fornecedor: { id: supplier_id.to_s },
      situacao: { valor: 0 },
      observacoes: "Pedido gerado automaticamente para #{items.count} itens do pedido de venda #{first_item.sale_order.numero}",
      itens: order_items
    }

    attempt = Attempt.new(
      kinds: :create_purchase_order,
      requisition: payload.to_json,
      external_reference: items.map(&:id).join(', '),
      bling_order_id: nil,
      bling_numero: nil
    )

    begin
      response = Bling::PurchaseOrders.create(payload)

      if response[:status] == 'success'
        SaleOrderItem.where(id: items.map(&:id)).update_all(
          bling_order_id: response[:id],
          bling_numero: response[:numero],
          purchase_order_created_at: Time.current
        )

        attempt.assign_attributes(
          status: :success,
          bling_order_id: response[:id],
          bling_numero: response[:numero],
          params: response[:response].to_json,
          message: "Pedido criado com sucesso (ID: #{response[:id]}, Número: #{response[:numero]})"
        )
      else
        error_message = response[:error] || 'Resposta inesperada'
        raise StandardError, "Erro na API Bling: #{error_message}"
      end

    rescue StandardError => e
      attempt.assign_attributes(
        status: :error,
        error: e.message.truncate(255),
        exception: e.class.to_s,
        message: "Falha ao criar pedido: #{e.message}".truncate(255),
        backtrace: e.backtrace&.first(5)&.join("\n")&.truncate(500)
      )
      raise e if Rails.env.development? || Rails.env.test?
    ensure
      attempt.save!
      Rails.logger.info "Attempt saved for items: #{items.map(&:id)}, Status: #{attempt.status}"
    end

    attempt
  end
end
