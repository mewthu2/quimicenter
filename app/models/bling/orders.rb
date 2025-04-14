# app/models/bling/orders.rb
module Bling
  class Orders < Base
    # Situações possíveis dos pedidos (códigos do Bling)
    SITUATIONS = {
      all: nil,
      draft: '0',       # Rascunho
      verified: '1',    # Verificado
      invoiced: '2',    # Faturado
      canceled: '3',    # Cancelado
      returned: '4',    # Devolvido
      partial: '5',     # Faturado Parcial
      completed: '9',   # Finalizado
      in_progress: '10' # Em Andamento
    }.freeze

    # Métodos de classe para interface simplificada
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
    end

    # Métodos de instância
    def get_all(page = 1, filters = {})
      filters = filters.symbolize_keys

      query_params = {
        pagina: page
      }

      # Mapeamento de filtros permitidos pela API
      allowed_filters = %i[
        idContato
        numero
        dataEmissaoInicial
        dataEmissaoFinal
        situacao
        idVendedor
        idLoja
        tipoIntegracao
        formasPagamento
        idCategoria
        idTransporte
        idRepresentante
        numeroPedidoLoja
        idsPedidos
      ]

      allowed_filters.each do |key|
        query_params[key] = filters[key] if filters[key].present?
      end

      query = query_params.to_query
      response = make_request(:get, "/pedidos/vendas?#{query}")
      parse_response(response)
    end

    def get(id)
      response = make_request(:get, "/pedidos/vendas/#{id}")
      parse_response(response)
    end

    def create(order_data)
      payload = { pedido: order_data }
      response = make_request(:post, "/pedidos/vendas", payload)
      parse_response(response)
    end

    def update(id, order_data)
      payload = { pedido: order_data }
      response = make_request(:put, "/pedidos/vendas/#{id}", payload)
      parse_response(response)
    end

    private

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