class UpdateAttemptsTable < ActiveRecord::Migration[7.0]
  def up
    remove_column :attempts, :tiny_order_id, :integer

    add_column :attempts, :bling_order_id, :bigint
    add_column :attempts, :bling_numero, :bigint
  end

  def down
    remove_column :attempts, :bling_order_id, :bigint
    remove_column :attempts, :bling_numero, :bigint

    add_column :attempts, :tiny_order_id, :integer
  end
end