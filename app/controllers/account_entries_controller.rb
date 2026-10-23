class AccountEntriesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :account_entry, :through => :account

  # GET /account_entries
  def index
    @query = AccountEntryQuery.new(params[:query],session,current_user)
    @account_entries = @query.apply_conditions(@account_entries).order('account_entries.date DESC, account_entries.id DESC').includes(:bill)
    if params[:output] == 'CSV'
      @filename = "account_entries.csv"
      render "index.csv"
    else
      @account_entries = @account_entries.paginate :page => params[:page]
    end
  end

  def update_cleared
    AccountEntry.update(params[:account_entries].keys,params[:account_entries].values)
    redirect_to account_account_entries_path @account
  end
end
