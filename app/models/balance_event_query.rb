class BalanceEventQuery
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_reader :start_date, :end_date, :payee_shareholder_id, :share_shareholder_id, :balance_shareholder_id, :with_text, 
    :bill_type_id, :can_use_running_total, :changed_at_start_date, :changed_at_end_date, :show_change_date_fields

  def self.grouped_shareholders(account)
    result = {'Active' => [], 'Inactive' => []}
    account.shareholders.order(:name).each do |sh|
      result[sh.status].push([sh.name, sh.id])
    end
    [['Active', result['Active']], ['Inactive', result['Inactive']]]
  end

  def self.grouped_shareholders_plus_all(account)
    result = {'All' => [['Anyone',nil]],'Active' => [], 'Inactive' => []}
    account.shareholders.order(:name).each do |sh|
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
      @start_date = parse_date(params[:start_date])
    else
      @start_date = Date.current.beginning_of_month - 3.months
    end
    @end_date = parse_date(params[:end_date]) if params[:end_date].present?

    @bill_type_id = (params[:bill_type_id] =~ /^[0-9]+$/ ? params[:bill_type_id].to_i : params[:bill_type_id]) if params[:bill_type_id].present?
    @with_text             = params[:with_text] if params[:with_text].present?
    @share_shareholder_id  = params[:share_shareholder_id].to_i if params[:share_shareholder_id].present?
    @payee_shareholder_id  = params[:payee_shareholder_id].to_i if params[:payee_shareholder_id].present?

    @changed_at_start_date = parse_date(params[:changed_at_start_date]) if params[:changed_at_start_date].present?
    @changed_at_end_date   = parse_date(params[:changed_at_end_date])   if params[:changed_at_end_date].present?
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

  # Search forms send yyyy-mm-dd from <input type="date">; ignore anything else.
  def parse_date(value)
    Date.iso8601(value)
  rescue Date::Error, TypeError
    nil
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
