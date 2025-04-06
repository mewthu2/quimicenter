# config/routes.rb
require 'sidekiq/web'

Rails.application.routes.draw do
  # Devise (autenticação)
  devise_for :user, skip: [:registrations]
  root to: 'home#index'

  # Sidekiq (monitoramento de jobs)
  authenticate :user do
    mount Sidekiq::Web => '/sidekiq'
  end

  # Dashboard
  resources :dashboard, only: [:index]

  # Pedidos de Venda
  resources :sales_orders, only: [:index, :show] do
    collection do
      get :export      # Exportação de dados
      get :search      # Busca avançada
    end

    member do
      post :cancel     # Cancelar pedido
      post :duplicate  # Duplicar pedido
    end
  end

  # Rota alternativa para filtro rápido de pedidos de venda
  get 'pedidos/:status', 
    to: 'sales_orders#index', 
    as: :filtered_sales_orders,
    constraints: { status: /all|completed|canceled|draft/ }

  # Pedidos de Compra
  resources :purchase_orders do
    collection do
      get 'load_items' # Carregar itens via AJAX
    end
  end

  # Rota alternativa para filtro rápido de pedidos de compra
  get 'pedidos-compra/:status', to: 'purchase_orders#index', as: :filtered_purchase_orders,constraints: { status: /all|draft|verified|received|partially_received|canceled|in_progress|completed/ }

  # Histórico de Tentativas
  resources :attempts, only: [:index] do
    collection do
      get :reprocess       # Reprocessar tentativas
      get :verify_attempts # Verificar tentativas
    end
  end

  # Contatos
  resources :contacts, only: [:index] do
    collection do
      get :suppliers  # Rota específica para fornecedores
    end
  end
end