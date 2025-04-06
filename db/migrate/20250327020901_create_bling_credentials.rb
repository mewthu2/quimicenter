# db/migrate/[timestamp]_create_bling_credentials.rb
class CreateBlingCredentials < ActiveRecord::Migration[7.0]
  def change
    create_table :bling_credentials do |t|
      t.string :access_token
      t.string :refresh_token
      t.datetime :expires_at
      t.string :bling_account_id
      t.string :token_type
      t.boolean :active, default: true

      t.timestamps
    end
  end
end