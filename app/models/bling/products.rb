# app/models/bling/products.rb
module Bling
  class Products < Base
    # Tipos de produto (códigos do Bling)
    PRODUCT_TYPES = {
      product: 'P',      # Produto
      service: 'S',      # Serviço
      package: 'E'       # Pacote/Kit
    }.freeze

    # Situações possíveis
    SITUATIONS = {
      active: 'A',       # Ativo
      inactive: 'I',     # Inativo
      deleted: 'E'       # Excluído
    }.freeze

    # Métodos de classe para interface simplificada
    class << self
      def all(page = 1, filters = {})
        new.get_all(page, filters)
      end

      def find(id)
        new.get(id)
      end

      def by_sku(sku)
        new.get_by_sku(sku)
      end

      def by_type(type, page = 1)
        type_code = PRODUCT_TYPES[type.to_sym] || type
        new.get_all(page, { tipo: type_code })
      end

      def active(page = 1)
        new.get_all(page, { situacao: SITUATIONS[:active] })
      end

      def with_stock(page = 1)
        new.get_all(page, { estoque: 'S' }) # 'S' = Com estoque
      end
    end

    # Métodos de instância
    def get_all(page = 1, filters = {})
      query = base_query(page, filters)
      response = make_request(:get, "/produtos?#{query}")
      parse_response(response)
    end

    def get(id)
      response = make_request(:get, "/produtos/#{id}")
      parse_response(response)
    end

    def get_by_sku(sku)
      response = make_request(:get, "/produtos/sku/#{sku}")
      parse_response(response)
    end

    def create(product_data)
      payload = { produto: product_data }
      response = make_request(:post, '/produtos', payload)
      parse_response(response)
    end

    def update(id, product_data)
      payload = { produto: product_data }
      response = make_request(:put, "/produtos/#{id}", payload)
      parse_response(response)
    end

    def delete(id)
      response = make_request(:delete, "/produtos/#{id}")
      { success: response.code == 204, id: }
    rescue RestClient::ExceptionWithResponse => e
      { success: false, error: e.message, id: }
    end

    # Métodos adicionais
    def categories
      response = make_request(:get, '/categorias/produtos')
      parse_response(response)
    end

    def search(term, page = 1)
      response = make_request(:get, "/produtos/pesquisa/#{term}?pagina=#{page}")
      parse_response(response)
    end

    private

    def base_query(page, filters = {})
      { pagina: page }.merge(filters).to_query
    end

    def parse_response(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      { error: 'Invalid JSON response', raw_response: response.body }
    end
  end
end