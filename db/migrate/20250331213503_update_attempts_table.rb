class UpdateAttemptsTable < ActiveRecord::Migration[7.0]
  def up
    remove_column :attempts, :tiny_order_id, :integer
    remove_column :attempts, :xml_nota, :text
    remove_column :attempts, :xml_sended, :boolean

    add_column :attempts, :bling_order_id, :bigint
    add_column :attempts, :bling_numero, :bigint
  end

  def down
    remove_column :attempts, :bling_order_id, :bigint
    remove_column :attempts, :bling_numero, :bigint

    add_column :attempts, :tiny_order_id, :integer
    add_column :attempts, :xml_nota, :text
    add_column :attempts, :xml_sended, :boolean
  end
end