class BillsController < ApplicationController
  before_filter :authenticate_user!
  respond_to :html

  # GET /bills
  def index
    @shareholder, @account = verify_account_access(current_user, params)
    @bills = @account.bills.order('bills.date DESC, bills.id DESC').includes(:shareholder, :bill_type, :bill_share_balance_entries, :bill_offset_balance_entry).paginate :page => params[:page]

    respond_with @bills
  end
end
