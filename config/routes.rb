Rails.application.routes.draw do
  # Google sign-in only (plan D1): no passwords, registrations or confirmations.
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }
  devise_scope :user do
    get    "users/sign_in",  to: "users/sessions#new",      as: :new_user_session
    delete "users/sign_out", to: "devise/sessions#destroy", as: :destroy_user_session
  end

  resources :accounts do
    get   "edit_pot",   :on => :member
    patch "update_pot", :on => :member

    resources :shareholders, :except => [:index, :show]
    resources :payees, :except => [:index, :show]
    resources :bill_types, :except => [:index, :show]

    resources :balance_events, :only => [:index]
    resources :shareholder_bills
    resources :account_bills
    resources :bills, :only => [] do
      get 'show_shares', :on => :member
    end

    resources :account_entries, :only => [:index] do
      post 'update_cleared', :on => :collection
    end
    resources :shareholder_account_entries
    resources :unbound_account_entries

    get "charts/bill_types_by_month", to: "charts#bill_types_by_month", as: :bill_types_by_month_chart
    get "charts/bill_types_by_month_for_current_user_line_chart",
        to: "charts#bill_types_by_month_for_current_user_line_chart",
        as: :bill_types_by_month_line_chart
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root :to => 'accounts#index'
end
