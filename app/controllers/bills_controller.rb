class BillsController < ApplicationController
  before_filter :authenticate_user!
  respond_to :html

  # GET /bills
  def index
    @shareholder, @account = verify_account_access(current_user, params)
    @bills = @account.bills.order(:entered_on,:id).all

    respond_with @bills
  end
end
