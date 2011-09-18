class BillsController < ApplicationController
  before_filter :authenticate_user!
  respond_to :html

  # GET /bills
  def index
    @shareholder, @account = verify_account_access(current_user, params)
    @bills = @account.bills.order('bills.date DESC, bills.id DESC').includes(:shareholder, :bill_type, :bill_share_balance_entries, :bill_offset_balance_entry).paginate :page => params[:page]

    # Include account entries for the earliest day of the bill list if we have all the bills for that day
    min_date, max_date = @bills.map {|bill| bill.date}.minmax
    include_min_date = (@bills.last.id == @account.bills.where(:date => min_date).minimum(:id))
    min_date += 1 unless include_min_date

    @account_entries = ShareholderAccountEntry.where(:date => min_date..max_date).order('date DESC, id DESC').includes(:shareholder)
    bills_by_date = @bills.group_by(&:date)
    account_entries_by_date = @account_entries.group_by(&:date)
    all_dates = (bills_by_date.keys + account_entries_by_date.keys).uniq.sort.reverse

    @bills_and_entries = []
    for d in all_dates
      @bills_and_entries += account_entries_by_date[d] if account_entries_by_date.key?(d)
      @bills_and_entries += bills_by_date[d] if bills_by_date.key?(d)
    end
  end
end
