class BalanceEventQuery
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_reader :start_date, :end_date, :payee_shareholder_id, :share_shareholder_id, :balance_shareholder_id, :with_text, 
    :bill_type_id, :can_use_running_total, :changed_at_start_date, :changed_at_end_date, :show_change_date_fields

  def self.grouped_shareholders
    result = {'Active' => [], 'Inactive' => []}
    Shareholder.order(:name).each do |sh|
      result[sh.status].push([sh.name, sh.id])
    end
    [['Active', result['Active']], ['Inactive', result['Inactive']]]
  end

  def self.grouped_shareholders_plus_all
    result = {'All' => [['Anyone',nil]],'Active' => [], 'Inactive' => []}
    Shareholder.order(:name).each do |sh|
      result[sh.status].push([sh.name, sh.id])
    end
    [['All',result['All']], ['Active', result['Active']], ['Inactive', result['Inactive']]]
  end

  def self.bill_types(account)
    [['All types of',nil]] +
    (AccountEntry.valid_entry_types.each{|item| [item,item] } + BillType.for_account(account).each.map{|row| [row.name,row.id]}).sort_by{|a| a[0] }
  end

  def initialize(params, session, user, account)
    @current_user = user
    params ||= {}
    if params[:start_date].present?
      @start_date = Date.strptime(params[:start_date],'%m-%d-%Y')
    else
      @start_date = Date.today.beginning_of_month - 3.months
    end
    @end_date = Date.strptime(params[:end_date],'%m-%d-%Y') if params[:end_date].present?

    @bill_type_id = (params[:bill_type_id] =~ /^[0-9]+$/ ? params[:bill_type_id].to_i : params[:bill_type_id]) if params[:bill_type_id].present?
    @with_text             = params[:with_text] if params[:with_text].present?
    @share_shareholder_id  = params[:share_shareholder_id].to_i if params[:share_shareholder_id].present?
    @payee_shareholder_id  = params[:payee_shareholder_id].to_i if params[:payee_shareholder_id].present?

    @changed_at_start_date = Date.strptime(params[:changed_at_start_date],'%m-%d-%Y') if params[:changed_at_start_date].present?
    @changed_at_end_date   = Date.strptime(params[:changed_at_end_date],'%m-%d-%Y')   if params[:changed_at_end_date].present?
    @show_change_date_fields = @changed_at_start_date.present? || @changed_at_end_date.present?

    if params[:balance_shareholder_id].present?
      @balance_shareholder_id = params[:balance_shareholder_id].to_i
    else
      @balance_shareholder_id = user.shareholder_for_account(account).id
    end
  end

  def persisted?
    false
  end

  def apply_conditions(balance_events)
    @can_use_running_total = true
    balance_events = balance_events.starting_on(start_date) if start_date
    balance_events = balance_events.ending_on(end_date)     if end_date

    if changed_at_start_date
      balance_events = balance_events.changed_at_start_date(changed_at_start_date)
      @can_use_running_total = false
    end
    if changed_at_end_date
      balance_events = balance_events.changed_at_end_date(changed_at_end_date)     if changed_at_end_date
      @can_use_running_total = false
    end
    if [changed_at_start_date, changed_at_end_date].any?
      balance_events = balance_events.join_bills_and_account_entries
    end
    if with_text
      balance_events = balance_events.with_text(with_text)
      @can_use_running_total = false
    end
    if payee_shareholder_id
      balance_events = balance_events.with_payee_shareholder_id(payee_shareholder_id)
      @can_use_running_total = false
    end
    if share_shareholder_id
      balance_events = balance_events.with_share_shareholder_id(share_shareholder_id)
      @can_use_running_total = false unless Shareholder.find(share_shareholder_id).user == @current_user
    end
    if bill_type_id.is_a?(Integer)
      balance_events = balance_events.with_bill_type_id(bill_type_id)
      @can_use_running_total = false
    elsif bill_type_id == 'Deposit'
      balance_events = balance_events.deposits
      @can_use_running_total = false
    elsif bill_type_id == 'Withdrawal'
      balance_events = balance_events.withdrawals
      @can_use_running_total = false
    end
    balance_events
  end
end

class BalanceEventsController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account

  # GET /balance_events
  def index
    @balance_events = @account.balance_events.accessible_by(current_ability)
    authorize! :show, BalanceEvent
    @q = BalanceEventQuery.new(params[:q], session, current_user, @account)
    @balance_events = @q.apply_conditions(@balance_events)
    @shareholder = Shareholder.find(@q.balance_shareholder_id)
    if params[:output] == 'CSV'
      if @balance_events.count > 250
        flash.now[:error] = "Exports cannot be for more than 250 entries"
      else
        @balance_events = @balance_events.default_order.all_includes
        bill_ids = @balance_events.map{|be| be.bill_id }.compact
        account_entry_ids = @balance_events.map{|be| be.account_entry_id }.compact
        shareholder_ids = BalanceEntry.
          where("bill_id IN (?) OR account_entry_id IN (?)",bill_ids, account_entry_ids).
          pluck("DISTINCT shareholder_id").compact
        @shareholders = Shareholder.order(:name).find(shareholder_ids)
        @filename = "house_bills.csv"
        render "index.csv"
      end
    else
      total_entries = @balance_events.count(:id)
      @paginated_balance_events = @balance_events.default_order.all_includes.paginate :page => params[:page], :total_entries => total_entries
      if @paginated_balance_events.total_pages > 1
        @sum_of_item_amounts = @balance_events.sum_of_amounts
        @sum_of_share_amounts = @balance_events.sum_of_share_amounts(@shareholder.id)
        @sum_of_offset_amounts = @balance_events.sum_of_offset_amounts(@shareholder.id)
      end
    end
  end
end
