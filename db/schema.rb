# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_04_14_032010) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "attempts", force: :cascade do |t|
    t.bigint "kinds"
    t.bigint "status"
    t.text "requisition"
    t.text "params"
    t.string "error"
    t.string "status_code"
    t.string "message"
    t.string "exception"
    t.string "classification"
    t.string "cause"
    t.string "url"
    t.string "user"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "bling_order_id"
    t.bigint "bling_numero"
    t.string "external_reference"
    t.index ["kinds", "external_reference", "status"], name: "index_attempts_on_kinds_and_external_reference_and_status"
  end

  create_table "bling_credentials", force: :cascade do |t|
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "expires_at"
    t.string "bling_account_id"
    t.string "token_type"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sale_order_item_supplies", force: :cascade do |t|
    t.bigint "sale_order_item_id", null: false
    t.bigint "supplier_id", null: false
    t.string "supplier_name"
    t.string "supplier_type"
    t.boolean "default", default: false
    t.datetime "last_sync_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sale_order_item_id", "supplier_id"], name: "index_item_supplier_unique", unique: true
    t.index ["sale_order_item_id"], name: "index_sale_order_item_supplies_on_sale_order_item_id"
    t.index ["supplier_id"], name: "index_sale_order_item_supplies_on_supplier_id"
  end

  create_table "sale_order_items", force: :cascade do |t|
    t.bigint "sale_order_id", null: false
    t.bigint "produto_id"
    t.string "produto_codigo"
    t.string "produto_descricao"
    t.decimal "quantidade", precision: 15, scale: 4
    t.decimal "valor_unitario", precision: 15, scale: 2
    t.decimal "valor_total", precision: 15, scale: 2
    t.string "unidade"
    t.decimal "desconto", precision: 15, scale: 2
    t.decimal "aliquota_ipi", precision: 15, scale: 2
    t.string "descricao_detalhada"
    t.jsonb "dados_adicionais"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "produto_estoque"
    t.index ["produto_codigo"], name: "index_sale_order_items_on_produto_codigo"
    t.index ["produto_id"], name: "index_sale_order_items_on_produto_id"
    t.index ["sale_order_id"], name: "index_sale_order_items_on_sale_order_id"
  end

  create_table "sale_orders", force: :cascade do |t|
    t.bigint "bling_id", null: false
    t.string "numero"
    t.string "numero_loja"
    t.date "data"
    t.date "data_saida"
    t.date "data_prevista"
    t.decimal "total_produtos", precision: 15, scale: 2
    t.decimal "total", precision: 15, scale: 2
    t.bigint "contato_id"
    t.string "contato_nome"
    t.string "contato_tipo_pessoa"
    t.string "contato_numero_documento"
    t.integer "situacao_id"
    t.string "situacao_valor"
    t.bigint "loja_id"
    t.datetime "last_sync_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bling_id"], name: "index_sale_orders_on_bling_id", unique: true
    t.index ["data"], name: "index_sale_orders_on_data"
    t.index ["numero"], name: "index_sale_orders_on_numero"
    t.index ["situacao_id"], name: "index_sale_orders_on_situacao_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "phone"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.string "unlock_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "sale_order_item_supplies", "sale_order_items"
  add_foreign_key "sale_order_items", "sale_orders"
end
