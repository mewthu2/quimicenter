module OrderReferenceHelper
  def generate_order_reference(order_data)
    # Converte para símbolos se for hash com strings
    data = order_data.deep_symbolize_keys
    
    # Extrai os componentes chave
    order_date = data[:data] || data['data']&.to_s || ''
    contact_id = data.dig(:contato, :id) || data.dig(:fornecedor, :id) || data.dig('contato', 'id') || data.dig('fornecedor', 'id') || ''
    
    # Formata a referência básica
    [order_date.to_s.strip, contact_id.to_s.strip].join('#')
  end
end