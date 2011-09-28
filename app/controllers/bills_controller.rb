class BillsController < ApplicationController
  before_filter :authenticate_user!
  respond_to :html

  # GET /bills
  def index
    @shareholder, @account = verify_account_access(current_user, params)
    @balance_events = @account.balance_entries.events.paginate :page => params[:page]
  end
end
