class AccountEntriesController < ApplicationController
  before_filter :authenticate_user!
  respond_to :html

  # GET /account_entries
  def index
    @shareholder, @account = verify_account_access(current_user, params)
    @account_entries = @account.account_entries.order('account_entries.entered_on DESC, account_entries.id DESC').includes(:bill).paginate :page => params[:page]

    respond_with(@account_entries)
  end
end
