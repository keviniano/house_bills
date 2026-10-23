class BalanceEventsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource :account

  # GET /balance_events
  def index
    @balance_events = @account.balance_events.accessible_by(current_ability)
    authorize! :show, BalanceEvent
    @q = BalanceEventQuery.new(params[:q], session, current_user, @account)
    @balance_events = @q.apply_conditions(@balance_events)
    @shareholder = Shareholder.find(@q.balance_shareholder_id)
    if params[:output] == 'CSV'
      return export_csv if @balance_events.count <= 250
      flash.now[:error] = "Exports cannot be for more than 250 entries"
    end

    total_entries = @balance_events.count(:id)
    @paginated_balance_events = @balance_events.default_order.all_includes.paginate :page => params[:page], :total_entries => total_entries
    if @paginated_balance_events.total_pages > 1
      @sum_of_item_amounts = @balance_events.sum_of_amounts
      @sum_of_share_amounts = @balance_events.sum_of_share_amounts(@shareholder.id)
      @sum_of_offset_amounts = @balance_events.sum_of_offset_amounts(@shareholder.id)
    end
  end

  private

  def export_csv
    balance_events = @balance_events.default_order.all_includes
    bill_ids = balance_events.map{|be| be.bill_id }.compact
    account_entry_ids = balance_events.map{|be| be.account_entry_id }.compact
    shareholder_ids = BalanceEntry.
      where("bill_id IN (?) OR account_entry_id IN (?)",bill_ids, account_entry_ids).
      distinct.pluck(:shareholder_id).compact
    shareholders = Shareholder.order(:name).find(shareholder_ids)
    send_data BalanceEventsCsv.new(balance_events, shareholders).to_csv,
      filename: "house_bills.csv", type: :csv
  end
end
