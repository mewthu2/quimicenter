# app/helpers/purchase_orders_helper.rb
module PurchaseOrdersHelper
  def purchase_status_text(situation)
    # Verifica se situation é um hash com a chave 'valor' ou se é o valor direto
    status_value = situation.is_a?(Hash) ? situation['valor'].to_s : situation.to_s
    
    status_map = {
      '0' => 'Rascunho',
      '1' => 'Verificado',
      '2' => 'Recebido',
      '3' => 'Parcialmente Recebido',
      '4' => 'Cancelado',
      '5' => 'Em Andamento',
      '9' => 'Finalizado'
    }

    status_map.fetch(status_value, "Desconhecido (#{status_value})")
  end

  def purchase_status_badge_class(situation)
    # Verifica se situation é um hash com a chave 'valor' ou se é o valor direto
    status_value = situation.is_a?(Hash) ? situation['valor'].to_s : situation.to_s
    
    class_map = {
      '0' => 'bg-secondary',    # Rascunho
      '1' => 'bg-info',         # Verificado
      '2' => 'bg-success',      # Recebido
      '3' => 'bg-primary',      # Parcialmente Recebido
      '4' => 'bg-danger',       # Cancelado
      '5' => 'bg-warning',      # Em Andamento
      '9' => 'bg-success'       # Finalizado
    }

    class_map.fetch(status_value, 'bg-dark')
  end

  # Opções de fornecedores para um produto específico
  def suppliers_options_for(product_id)
    # Primeiro busca os fornecedores preferenciais para este produto
    preferred_suppliers = preferred_suppliers_for(product_id)

    # Combina fornecedores preferenciais com a lista geral
    options = preferred_suppliers.map do |supplier|
      ["★ #{supplier[:name]}", supplier[:id], { class: 'text-success' }]
    end

    # Adiciona os demais fornecedores
    @suppliers.each do |supplier|
      unless preferred_suppliers.any? { |s| s[:id] == supplier['id'] }
        options << [supplier['nome'], supplier['id']]
      end
    end

    options_for_select(options)
  end

  # Identifica fornecedores preferenciais para um produto
  def preferred_suppliers_for(product_id)
    # Implementação básica - você deve adaptar para sua lógica de negócios
    # Pode ser baseado em:
    # 1. Fornecedor com menor preço
    # 2. Fornecedor com melhor prazo
    # 3. Cadastro específico no seu sistema
    
    # Exemplo: pega os 2 primeiros fornecedores como preferenciais
    @suppliers.first(2).map do |supplier|
      { id: supplier['id'], name: supplier['nome'] }
    end
  end

  # Método completo para fornecedor preferencial (individual)
  def preferred_supplier_for(product_id)
    preferred_suppliers_for(product_id).first
  end

  # Formata a data para exibição
  def format_date(date_string)
    return 'N/A' if date_string.blank?
    
    begin
      Date.parse(date_string).strftime('%d/%m/%Y')
    rescue
      date_string
    end
  end
end