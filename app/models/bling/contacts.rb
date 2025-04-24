module Bling
  class Contacts < Base
    CONTACT_TYPES = {
      supplier: 'Fornecedor',
      customer: 'Cliente',
      both: 'Cliente e Fornecedor'
    }.freeze

    class << self
      def all(filters = {})
        new.get_all(filters)
      end

      def find(id)
        new.get(id)
      end

      def by_type(type, filters = {})
        type_id = type.is_a?(String) ? type : find_type_id(type)
        new.get_all(filters.merge(tipo: type_id))
      end

      def suppliers(filters = {})
        by_type(:supplier, filters)
      end

      def find_type_id(type_name)
        response = make_request(:get, '/contatos/tipos')
        type = JSON.parse(response.body)['data'].find { |t| t['descricao'] == type_name }
        type['id'] if type
      rescue StandardError => e
        nil
      end
    end

    def get_all(filters = {})
      filters[:idsContatos] = filters[:idsContatos].join(',') if filters[:idsContatos].is_a?(Array)

      filters = filters.compact

      query = filters.to_query
      response = make_request(:get, "/contatos?#{query}")
      parse_response(response)
    end

    def get(id)
      response = make_request(:get, "/contatos/#{id}")
      parse_response(response)
    end

    private

    def parse_response(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      { error: "Invalid JSON response", raw_response: response.body }
    end
  end
end