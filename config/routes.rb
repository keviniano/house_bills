Rails.application.routes.draw do
  get "bill_account_entries/show"

  get "shareholder_account_entries/new"

  get "shareholder_account_entries/create"

  get "shareholder_account_entries/edit"

  get "shareholder_account_entries/update"

  get "shareholder_account_entries/index"

  get "shareholder_account_entries/destroy"

  get "shareholder_account_entries/show"

  devise_for :users

  resources :accounts do
    get   "edit_pot",   :on => :member
    patch "update_pot", :on => :member

    resources :shareholders, :except => [:index, :show]
    resources :payees, :except => [:index, :show]
    resources :bill_types, :except => [:index, :show]

    resources :balance_events, :only => [:index] do
      get 'chart', :on => :collection
    end
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

    get 'charts(/:action)' => 'charts#:action', :as => :charts
  end

  get 'charts(/:action)' => 'charts#:action', :as => :charts

  root :to => 'accounts#index'

  # if Rails.env.development?
  #   app = ActionDispatch::Static.new(
  #     lambda{ |env| [404, { 'X-Cascade' => 'pass'}, []] },
  #     Rails.application.config.paths['public'].first,
  #     Rails.application.config.static_cache_control
  #   )

  #   mount app, :at => '/', :as => :public
  # end

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
