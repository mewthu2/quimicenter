# app/models/bling/product_suppliers.rb
module Bling
  class ProductSuppliers < Base
    # Como Usar:

    # 1. Listar fornecedores de um produto
    # Bling::ProductSuppliers.list(product_id: 12345)

    # 2. Listar com paginação e limite
    # Bling::ProductSuppliers.list(product_id: 12345, page: 2, limit: 50)

    # 3. Buscar fornecedor específico de um produto
    # Bling::ProductSuppliers.find(product_id: 12345, supplier_id: 67890)

    # 4. Associar fornecedor a um produto
    # Bling::ProductSuppliers.create(product_id: 12345, supplier_id: 67890, cost_price: 50.0)

    # 5. Remover fornecedor de um produto
    # Bling::ProductSuppliers.remove(product_id: 12345, supplier_id: 67890)

    class << self
      def list(product_id:, page: 1, limit: 100)
        new.list(product_id, page, limit)
      end

      def find(product_id:, supplier_id:)
        new.find(product_id, supplier_id)
      end

      def create(product_id:, supplier_id:, cost_price: nil)
        new.create(product_id, supplier_id, cost_price)
      end

      def remove(product_id:, supplier_id:)
        new.remove(product_id, supplier_id)
      end
    end

    def list(product_id, page = 1, limit = 100)
      query = {
        pagina: page,
        limite: limit,
        idProduto: product_id
      }.to_query

      response = make_request(:get, "/produtos/fornecedores?#{query}")
      parse_response(response)
    end

    def find(product_id, supplier_id)
      query = {
        idProduto: product_id,
        idFornecedor: supplier_id
      }.to_query

      response = make_request(:get, "/produtos/fornecedores?#{query}")
      parse_response(response)
    end

    def create(product_id, supplier_id, cost_price = nil)
      payload = {
        fornecedor: {
          id: supplier_id,
          precoCusto: cost_price
        }.compact
      }

      response = make_request(:post, "/produtos/#{product_id}/fornecedores", payload)
      parse_response(response)
    end

    def remove(product_id, supplier_id)
      response = make_request(:delete, "/produtos/#{product_id}/fornecedores/#{supplier_id}")
      { success: response.code == 200 }
    rescue RestClient::ExceptionWithResponse => e
      { success: false, error: e.message }
    end

    private

    def parse_response(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      { error: "Invalid JSON response", raw_response: response.body }
    end
  end
end