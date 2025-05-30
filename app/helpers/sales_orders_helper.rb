# app/helpers/sales_orders_helper.rb
module SalesOrdersHelper
  # Formata data no padrão brasileiro
  def format_date(date_string)
    return 'N/A' if date_string.blank? || date_string == '0000-00-00'

    begin
      Date.parse(date_string).strftime('%d/%m/%Y')
    rescue
      date_string
    end
  end

  # Formata CPF/CNPJ
  def format_document(doc, type)
    return 'N/A' if doc.blank?

    if type == 'J' # CNPJ
      doc.gsub(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '\1.\2.\3/\4-\5')
    else # CPF
      doc.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\1.\2.\3-\4')
    end
  rescue
    doc
  end

  def safe_stock_value(item)
    return 0 if item.produto_estoque.nil?
    item.produto_estoque.to_i
  end

  def stock_status_class(item)
    stock = safe_stock_value(item)
    
    if stock < 0
      'stock-negative bg-danger text-white'
    elsif stock == 0
      'stock-zero bg-warning text-dark'
    else
      'stock-positive bg-success text-white'
    end
  end

  def stock_priority_level(item)
    stock = safe_stock_value(item)
    
    if stock <= -10
      'critical'
    elsif stock <= -5
      'high'
    else
      'medium'
    end
  end

  def stock_priority_icon(item)
    level = stock_priority_level(item)
    
    case level
    when 'critical'
      '<i class="fas fa-radiation text-warning" title="Prioridade Crítica"></i>'.html_safe
    when 'high'
      '<i class="fas fa-exclamation-circle text-warning" title="Prioridade Alta"></i>'.html_safe
    else
      '<i class="fas fa-arrow-down text-warning" title="Prioridade Média"></i>'.html_safe
    end
  end

  # Mapeamento completo dos status específicos da sua API
  SPECIFIC_STATUS_MAP = {
    # IDs específicos do seu sistema
    430301 => { text: 'Em digitação', class: 'bg-secondary' },
    430302 => { text: 'Verificado', class: 'bg-info' },
    430303 => { text: 'Atendido', class: 'bg-success' },
    430304 => { text: 'Cancelado', class: 'bg-danger' },
    430305 => { text: 'Devolvido', class: 'bg-warning' },
    430306 => { text: 'Em aberto', class: 'bg-light text-dark' },
    430309 => { text: 'Finalizado', class: 'bg-success' },
    430310 => { text: 'Em andamento', class: 'bg-info' },
    430311 => { text: 'Venda agenciada', class: 'bg-purple' }
  }.freeze

  # Mapeamento genérico para situações padrão
  GENERIC_STATUS_MAP = {
    0 => { text: 'Em digitação', class: 'bg-secondary' },
    1 => { text: 'Verificado', class: 'bg-info' },
    2 => { text: 'Atendido', class: 'bg-success' },
    3 => { text: 'Cancelado', class: 'bg-danger' },
    4 => { text: 'Devolvido', class: 'bg-warning' },
    5 => { text: 'Parcial', class: 'bg-primary' },
    6 => { text: 'Em aberto', class: 'bg-light text-dark' },
    9 => { text: 'Finalizado', class: 'bg-success' },
    10 => { text: 'Em andamento', class: 'bg-info' },
    11 => { text: 'Venda agenciada', class: 'bg-purple' }
  }.freeze

  # Retorna o texto descritivo do status
  def status_text(situation)
    return 'N/A' unless situation.is_a?(Hash) && situation['id'].present?

    status = SPECIFIC_STATUS_MAP[situation['id']] || GENERIC_STATUS_MAP[situation['id']]
    status&.fetch(:text, "Desconhecido (#{situation['id']})")
  end

  def format_quantity_safe(value)
    return '0' if value.nil?
    number_with_precision(value, precision: 2)
  end

  # Retorna a classe CSS para o badge do status
  def status_badge_class(situation)
    return 'bg-dark' unless situation.is_a?(Hash) && situation['id'].present?

    status = SPECIFIC_STATUS_MAP[situation['id']] || GENERIC_STATUS_MAP[situation['id']]
    status&.fetch(:class, 'bg-dark')
  end

  # Retorna o badge completo (texto + classe CSS)
  def status_badge(situation)
    return unless situation.is_a?(Hash) && situation['id'].present?
    
    text = status_text(situation)
    css_class = status_badge_class(situation)
    content_tag(:span, text, class: "badge #{css_class}")
  end

  # Método auxiliar para formatar valores monetários
  def format_currency(value)
    number_to_currency(value, unit: "R$ ", separator: ",", delimiter: ".", precision: 2)
  rescue
    value.to_s
  end
end