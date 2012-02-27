class AccountEntriesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :account_entry, :through => :account

  # GET /account_entries
  def index
    @account_entries = @account_entries.order('account_entries.date DESC, account_entries.id DESC').includes(:bill).paginate :page => params[:page]
  end
end
