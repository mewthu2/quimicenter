# db/migrate/[timestamp]_create_sale_orders.rb
class CreateSaleOrders < ActiveRecord::Migration[6.1]
  def change
    create_table :sale_orders do |t|
      t.bigint :bling_id, null: false
      t.string :numero
      t.string :numero_loja
      t.date :data
      t.date :data_saida
      t.date :data_prevista
      t.decimal :total_produtos, precision: 15, scale: 2
      t.decimal :total, precision: 15, scale: 2
      t.bigint :contato_id
      t.string :contato_nome
      t.string :contato_tipo_pessoa
      t.string :contato_numero_documento
      t.integer :situacao_id
      t.string :situacao_valor
      t.bigint :loja_id
      t.datetime :last_sync_at

      t.timestamps
    end

    add_index :sale_orders, :bling_id, unique: true
    add_index :sale_orders, :numero
    add_index :sale_orders, :data
    add_index :sale_orders, :situacao_id
  end
end