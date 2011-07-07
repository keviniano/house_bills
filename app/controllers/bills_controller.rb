class BillsController < ApplicationController
  before_filter :authenticate_user!
  respond_to :html

  # GET /bills
  def index
    @shareholder, @account = verify_account_access(current_user, params)
    @bills = @account.bills.order('bills.entered_on DESC, bills.id DESC').all

    respond_with @bills
  end
end
