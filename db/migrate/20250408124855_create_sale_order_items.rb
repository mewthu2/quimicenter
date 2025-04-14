class CreateSaleOrderItems < ActiveRecord::Migration[7.2]
  def change
    create_table :sale_order_items do |t|
      t.references :sale_order, null: false, foreign_key: true
      t.bigint :produto_id
      t.string :produto_codigo
      t.string :produto_descricao
      t.decimal :quantidade, precision: 15, scale: 4
      t.decimal :valor_unitario, precision: 15, scale: 2
      t.decimal :valor_total, precision: 15, scale: 2
      t.string :unidade
      t.decimal :desconto, precision: 15, scale: 2
      t.decimal :aliquota_ipi, precision: 15, scale: 2
      t.string :descricao_detalhada
      t.jsonb :dados_adicionais

      t.timestamps
    end

    add_index :sale_order_items, :produto_id
    add_index :sale_order_items, :produto_codigo
  end
end