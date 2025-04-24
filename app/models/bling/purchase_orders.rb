module Bling
  class PurchaseOrders < Base
    SITUATIONS = {
      all: nil,
      draft: '0',
      verified: '1',
      received: '2',
      partially_received: '3',
      canceled: '4',
      in_progress: '5',
      completed: '9'
    }.freeze

    class << self
      def all(page = 1, filters = {})
        new.get_all(page, filters)
      end

      def find(id)
        new.get(id)
      end

      def by_situation(situation, page = 1)
        situation_code = SITUATIONS[situation.to_sym] || situation
        new.get_all(page, { situacao: situation_code })
      end

      def create(order_data)
        new.create(order_data)
      end

      def update(id, order_data)
        new.update(id, order_data)
      end

      def by_supplier(supplier_id, page = 1)
        new.get_all(page, { idFornecedor: supplier_id })
      end
    end

    def get_all(page = 1, filters = {})
      response = make_request(:get, "/pedidos/compras?#{base_query(page, filters)}")
      parse_response(response)
    end

    def get(id)
      response = make_request(:get, "/pedidos/compras/#{id}")
      parse_response(response)
    end

    def create(order_data)
      data = order_data.deep_symbolize_keys

      payload = {
        fornecedor: {
          id: data.dig(:fornecedor, :id).to_s
        },
        itens: build_items(data[:itens]),
        data: data[:data].presence || Date.today.strftime('%Y-%m-%d'),
        dataPrevista: data[:dataPrevista].presence || (Date.today + 7.days).strftime('%Y-%m-%d'),
        situacao: {
          valor: data.dig(:situacao, :valor) || 0
        }
      }

      payload[:totalProdutos] = payload[:itens].sum { |i| i[:quantidade].to_i }
      payload[:total] = payload[:itens].sum { |i| i[:valor].to_f * i[:quantidade].to_f }.round(2)

      Rails.logger.info "[Bling] Enviando pedido: #{payload.to_json}"

      response = make_request(:post, '/pedidos/compras', payload)
      parsed_response = parse_response(response)

      if successful_response?(response, parsed_response)
        build_success_response(parsed_response)
      else
        handle_api_error(response)
      end
    rescue RestClient::ExceptionWithResponse => e
      handle_api_error(e.response)
    rescue => e
      Rails.logger.error "[Bling] Erro ao criar pedido: #{e.message}"
      build_error_response(e)
    end

    def update(id, order_data)
      response = make_request(:put, "/pedidos/compras/#{id}", order_data)
      parse_response(response)
    end

    private

    def build_items(items_data)
      Array(items_data).map do |item|
        next unless item.present?

        {
          descricao: item[:descricao].to_s,
          valor: item[:valor].to_f.positive? ? item[:valor].to_f : 0.01,
          codigoFornecedor: item[:codigo].to_s,
          unidade: item[:unidade].presence || 'UN',
          quantidade: item[:quantidade].to_f,
          aliquotaIPI: item[:aliquotaIPI].to_f,
          descricaoDetalhada: item[:descricaoDetalhada].presence || item[:descricao].to_s,
          produto: {
            id: item.dig(:produto, :id).to_s,
            codigo: item[:codigo].to_s
          }
        }.compact
      end.compact
    end

    def successful_response?(response, parsed_response)
      (response.code == 201 || response.code == 200) &&
      (parsed_response['id'].present? || (parsed_response['data'].is_a?(Hash) && parsed_response['data']['id'].present?))
    end

    def build_success_response(parsed_response)
      success_data = if parsed_response['data'].is_a?(Hash)
                        {
                          id: parsed_response['data']['id'],
                          numero: parsed_response['data']['numero'] || parsed_response['data']['number']
                        }
                     else
                        {
                          id: parsed_response['id'],
                          numero: parsed_response['numero'] || parsed_response['number']
                        }
                     end

      {
        status: 'success',
        id: success_data[:id],
        numero: success_data[:numero],
        response: parsed_response
      }
    end

    def build_error_response(error)
      {
        status: 'error',
        error: error.message,
        exception: error.class.to_s,
        backtrace: error.backtrace.first(3)
      }
    end

    def handle_api_error(response)
      error_response = parse_error_response(response)
      log_level = response.code.to_i >= 500 ? :error : :warn

      Rails.logger.public_send(log_level, "[Bling] Erro #{response.code}: #{error_response}")

      {
        status: 'error',
        error: error_response['error'] || error_response['description'] || "Erro na API Bling",
        status_code: response.code,
        full_response: error_response
      }
    end

    def parse_error_response(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      { error: response.body.presence || "Resposta vazia da API" }
    end

    def base_query(page, filters = {})
      { pagina: page }.merge(filters).to_query
    end

    def parse_response(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      { error: "Invalid JSON response", raw_response: response.body }
    end
  end
end