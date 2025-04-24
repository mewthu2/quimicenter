# app/models/bling/sales_orders.rb
module Bling
  class SalesOrders < Base
    # Como Usar:

    # # 1. Consulta de Pedidos
    # Todos os pedidos (paginado)
    # Bling::SalesOrders.all(1)

    # # Pedidos por situação
    # Bling::SalesOrders.by_situation(:completed) # Finalizados
    # Bling::SalesOrders.by_situation(5)          # Faturados Parcialmente

    # # Pedido específico
    # Bling::SalesOrders.find(12345)

    # # 2. Criação de Pedido
    # order_data = {
    #   numero: "1001",
    #   data: Date.today.to_s,
    #   cliente: {
    #     nome: "Cliente Exemplo",
    #     tipoPessoa: "J",
    #     cpf_cnpj: "12.345.678/0001-99",
    #     ie: "123.456.789",
    #     endereco: "Rua Exemplo, 123",
    #     cidade: "São Paulo",
    #     uf: "SP",
    #     cep: "01234-567"
    #   },
    #   itens: [
    #     {
    #       codigo: "PROD001",
    #       descricao: "Produto Exemplo",
    #       qtde: 2,
    #       vlr_unit: 150.50,
    #       un: "UN"
    #     }
    #   ],
    #   parcelas: [
    #     {
    #       vlr: 301.00,
    #       data: Date.today.next_month.to_s
    #     }
    #   ]
    # }

    # Bling::SalesOrders.create(order_data)

    # # 3. Atualização e Cancelamento
    # Atualizar pedido
    # Bling::SalesOrders.update(12345, { obs: "Entregar antes das 18h" })

    # # Cancelar pedido
    # Bling::SalesOrders.cancel(12345)

    # Estrutura Completa de um Pedido:
    # {
    #   "id": 12345,
    #   "numero": "1001",
    #   "data": "2023-05-15",
    #   "cliente": {
    #     "id": 54321,
    #     "nome": "Cliente Exemplo",
    #     "cpf_cnpj": "12.345.678/0001-99"
    #   },
    #   "itens": [
    #     {
    #       "id": 987,
    #       "codigo": "PROD001",
    #       "descricao": "Produto Exemplo",
    #       "qtde": 2,
    #       "vlr_unit": 150.50,
    #       "vlr_total": 301.00
    #     }
    #   ],
    #   "parcelas": [
    #     {
    #       "id": 456,
    #       "vlr": 301.00,
    #       "data": "2023-06-15",
    #       "obs": "Parcela única"
    #     }
    #   ],
    #   "total": 301.00,
    #   "situacao": "9",
    #   "loja": {
    #     "id": 1,
    #     "nome": "Matriz"
    #   }
    # }

    # Situações possíveis dos pedidos (códigos do Bling)
    SITUATIONS = {
      draft: 0,         # Rascunho
      verified: 1,      # Verificado
      invoiced: 2,      # Faturado
      canceled: 3,      # Cancelado
      returned: 4,      # Devolvido
      partial: 5,       # Faturado Parcialmente
      completed: 9,     # Finalizado
      in_progress: 10   # Em Andamento
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

      def create(order_data)
        new.create(order_data)
      end

      def update(id, order_data)
        new.update(id, order_data)
      end

      def cancel(id)
        new.cancel(id)
      end
    end

    # Métodos de instância
    def get_all(page = 1, filters = {})
      query = base_query(page, filters)
      response = make_request(:get, "/pedidos/vendas?#{query}")
      parse_response(response)
    end

    def get(id)
      response = make_request(:get, "/pedidos/vendas/#{id}")
      parse_response(response)
    end

    def create(order_data)
      payload = { pedido: prepare_order_data(order_data) }
      response = make_request(:post, '/pedidos/vendas', payload)
      parse_response(response)
    end

    def update(id, order_data)
      payload = { pedido: prepare_order_data(order_data) }
      response = make_request(:put, '/pedidos/vendas/#{id}', payload)
      parse_response(response)
    end

    def cancel(id)
      response = make_request(:delete, "/pedidos/vendas/#{id}")
      { success: response.code == 200, id: }
    rescue RestClient::ExceptionWithResponse => e
      { success: false, error: e.message, id: }
    end

    private

    def base_query(page, filters = {})
      { pagina: page }.merge(filters).to_query
    end

    def prepare_order_data(data)
      data.transform_values do |value|
        if value.is_a?(Hash)
          prepare_order_data(value)
        elsif value.is_a?(Numeric)
          value.to_f
        else
          value
        end
      end
    end

    def parse_response(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      { error: 'Invalid JSON response', raw_response: response.body }
    end
  end
end