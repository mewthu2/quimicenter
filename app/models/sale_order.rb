# app/models/sale_order.rb
class SaleOrder < ApplicationRecord
  validates :bling_id, presence: true, uniqueness: true

  has_many :sale_order_items, dependent: :destroy

  enum situacao_id: {
    draft: 0,        # Rascunho
    verified: 1,     # Verificado
    invoiced: 2,     # Faturado
    canceled: 3,     # Cancelado
    returned: 4,     # Devolvido
    partial: 5,      # Faturado Parcial
    completed: 9,    # Finalizado
    in_progress: 10  # Em Andamento
  }, _prefix: :status

  def self.sync_from_bling(page: 1, filters: {})
    response = Bling::Orders.all(page, filters)
    response['data'] || []
  end

  def self.create_or_update_from_bling(order_data)
    return nil unless order_data.present? && order_data['id'].present?

    situacao_id = order_data.dig('situacao', 'id')
    situacao_id = SaleOrder.situacao_ids.key?(situacao_id.to_i) ? situacao_id : 0

    order = SaleOrder.find_or_initialize_by(bling_id: order_data['id'])

    order.assign_attributes(
      numero: order_data['numero'],
      numero_loja: order_data['numeroLoja'],
      data: order_data['data'],
      data_saida: order_data['dataSaida'],
      data_prevista: order_data['dataPrevista'],
      total_produtos: order_data['totalProdutos'],
      total: order_data['total'],
      contato_id: order_data.dig('contato', 'id'),
      contato_nome: order_data.dig('contato', 'nome'),
      contato_tipo_pessoa: order_data.dig('contato', 'tipoPessoa'),
      contato_numero_documento: order_data.dig('contato', 'numeroDocumento'),
      situacao_id:,
      situacao_valor: order_data.dig('situacao', 'valor'),
      loja_id: order_data.dig('loja', 'id'),
      last_sync_at: Time.current
    )

    ActiveRecord::Base.transaction do
      order.save!

      if order_data['itens'].present?
        sync_order_items(order, order_data['itens'])
      else
        Rails.logger.warn "Pedido #{order_data['id']} sincronizado sem itens"
      end
    end

    order
  rescue StandardError => e
    Rails.logger.error "Error syncing order #{order_data['id']}: #{e.message}"
    nil
  end

  def self.sync_order_items(order, items_data)
    incoming_ids = items_data.map { |i| i.dig('produto', 'id').to_s }.compact

    order.sale_order_items.where.not(produto_id: incoming_ids).destroy_all

    items_data.each do |item_data|
      produto_id = item_data.dig('produto', 'id')
      next unless produto_id.present?

      item = order.sale_order_items.find_or_initialize_by(produto_id:)
      stock = current_stock_for(item_data.dig('produto', 'id'))

      print "Produto: #{item_data.dig('produto', 'id')}, Estoque: #{stock}\n"

      item.assign_attributes(
        sale_order_id: order.id,
        produto_id: item_data.dig('produto', 'id'),
        produto_codigo: item_data['codigo'],
        produto_descricao: item_data['descricao'],
        produto_estoque: stock,
        quantidade: item_data['quantidade'],
        valor_unitario: item_data['valor'],
        valor_total: item_data['total'],
        unidade: item_data['unidade'],
        desconto: item_data['desconto'],
        aliquota_ipi: item_data['aliquotaIPI'],
        descricao_detalhada: item_data['descricaoDetalhada'],
        dados_adicionais: item_data.except('produto', 'id', 'codigo', 'descricao', 'quantidade', 'valor', 'total', 'unidade', 'desconto', 'aliquotaIPI', 'descricaoDetalhada')
      )

      item.save!
    end
  end

  def self.current_stock_for(product_id)
    return 0 unless product_id.present?

    begin
      response = Bling::Products.find(product_id)
      stock = response.dig('data', 'estoque', 'saldoVirtualTotal') || response.dig('data', 'estoqueAtual') || 0
      stock.to_i
    rescue StandardError => e
      Rails.logger.error "Erro ao buscar estoque para #{product_id}: #{e.message}"
      0
    end
  end
end