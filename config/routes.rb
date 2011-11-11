HouseBills::Application.routes.draw do
  get "bill_account_entries/show"

  get "shareholder_account_entries/new"

  get "shareholder_account_entries/create"

  get "shareholder_account_entries/edit"

  get "shareholder_account_entries/update"

  get "shareholder_account_entries/index"

  get "shareholder_account_entries/destroy"

  get "shareholder_account_entries/show"

  devise_for :users

  resources :accounts, :except => :show do 
    get "edit_pot", :on => :member
    put "update_pot", :on => :member
  
    resources :balance_entries, :only => [:index]
    resources :shareholder_bills
    resources :account_bills

    resources :account_entries
    resources :shareholder_account_entries
    resources :bill_account_entries
    resources :unbound_account_entries 
    
    resources :payees
    resources :bill_types
  end

  root :to => 'account_entries#index'

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
