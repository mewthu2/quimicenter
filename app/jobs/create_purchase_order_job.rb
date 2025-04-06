class CreatePurchaseOrderJob < ApplicationJob
  def perform(purchase_order_data)
    data = purchase_order_data.deep_symbolize_keys

    selected_orders = data[:selected_orders].is_a?(String) ? 
                     data[:selected_orders].split(' ').join(', ') : 
                     Array(data[:selected_orders]).join(', ')

    attempt = Attempt.new(
      kinds: :create_purchase_order,
      requisition: data.to_json,
      external_reference: selected_orders,
      bling_order_id: nil,
      bling_numero: nil
    )

    begin
      final_payload = {
        data: data[:data],
        dataPrevista: data[:dataPrevista],
        fornecedor: { id: data.dig(:fornecedor, :id).to_s },
        situacao: { valor: data.dig(:situacao, :valor) || 0 },
        observacoes: data[:observacoes] || 'Pedido gerado automaticamente',
        itens: data[:itens].map do |item|
          {
            descricao: item[:descricao],
            codigoFornecedor: item[:codigo],
            unidade: item[:unidade] || 'UN',
            valor: item[:valor].to_f.positive? ? item[:valor].to_f : 0.01,
            quantidade: item[:quantidade].to_f,
            aliquotaIPI: item[:aliquotaIPI].to_f,
            descricaoDetalhada: item[:descricaoDetalhada] || item[:descricao],
            produto: { 
              id: item.dig(:produto, :id).to_s,
              codigo: item[:codigo]
            }.compact
          }.compact
        end
      }.compact

      response = Bling::PurchaseOrders.create(final_payload)

      if response[:status] == 'success'
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
      Rails.logger.info "Attempt saved for orders: #{selected_orders}, Status: #{attempt.status}"
    end

    attempt
  end
end