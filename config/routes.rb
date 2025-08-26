require 'sidekiq/web'

Rails.application.routes.draw do
  devise_for :user, skip: [:registrations]
  root to: 'home#index'

  authenticate :user do
    mount Sidekiq::Web => '/sidekiq'
  end

  resources :dashboard, only: [:index]

  resource :sync_configuration, only: [:show, :update] do
    post :test_sync
    delete :cleanup_data
  end

  resources :sales_orders, only: [:index, :show] do
    collection do
      get :export_negative_stock
      get :search
      get :search_supplier_bling
      post :add_supplier_to_item
      get :export_negative_stock
      post :save_multiple_items
      patch :bulk_ignore_items
      patch :bulk_restore_items
    end

    member do
      post :cancel
      post :duplicate
      patch :save_item
      patch :ignore_item
      patch :restore_item
      post :add_supplier_to_item
    end
  end


  get 'pedidos/:status', to: 'sales_orders#index', as: :filtered_sales_orders,
      constraints: { status: /all|completed|canceled|draft/ }

  resources :purchase_orders do
    collection do
      get 'load_items'
    end
  end

  get 'pedidos-compra/:status', to: 'purchase_orders#index', as: :filtered_purchase_orders,
      constraints: { status: /all|draft|verified|received|partially_received|canceled|in_progress|completed/ }

  resources :attempts, only: [:index] do
    collection do
      get :reprocess
      get :verify_attempts
    end
  end

  resources :contacts, only: [:index] do
    collection do
      get :suppliers
    end
  end

  resources :sale_order_items do
    collection do
      get :index
      post :process_multiple
      post :ignore_multiple
    end

    member do
      post :assign_supplier
      patch :update_item
      post :process_item
      post :ignore_item
      get :item_details
    end
  end
end
