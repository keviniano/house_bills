class BalanceEventQuery
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_reader :start_date, :end_date, :payee_shareholder_id, :with_text, :share_shareholder_id, :bill_type_id, :can_use_running_total

  def self.grouped_shareholders
    # ['Anyone',nil] + Shareholder.order(:name).map{|sh| [sh.name, sh.id]}
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

  def initialize(params,session,user)
    params ||= {}
    @current_user = user
    @account_id = session[:account_id]
    if params[:start_date].present?
      @start_date = Date.strptime(params[:start_date],'%m-%d-%Y') 
    else
      @start_date = Date.today - 3.months
    end
    unless params[:chart] == true
      @with_text = params[:with_text] if params[:with_text].present?
      @end_date = Date.strptime(params[:end_date],'%m-%d-%Y') if params[:end_date].present?
      @share_shareholder_id = params[:share_shareholder_id].to_i if params[:share_shareholder_id].present?
      @payee_shareholder_id = params[:payee_shareholder_id].to_i if params[:payee_shareholder_id].present?
      @bill_type_id = (params[:bill_type_id] =~ /^[0-9]+$/ ? params[:bill_type_id].to_i : params[:bill_type_id]) if params[:bill_type_id].present?
    end
  end

  def persisted?
    false
  end

  def apply_conditions(balance_events)
    @can_use_running_total = true
    balance_events = balance_events.starting_on(start_date) if start_date
    balance_events = balance_events.ending_on(end_date) if end_date
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
    @query = BalanceEventQuery.new(params[:query],session,current_user)
    @balance_events = @query.apply_conditions(@balance_events)
    @shareholder = current_user.shareholder_for_account(@account)
    if params[:output] == 'CSV'
      if @balance_events.count > 250 || (@balance_events.maximum(:date) - @balance_events.minimum(:date)).days > 93.days
        flash.now[:error] = "Exports cannot be for more than 250 entries or periods longer than 3 months (whichever is less)"
      else
        @shareholders = @balance_events.unique_shareholders
        @balance_events = @balance_events.default_order.all_includes
        @filename = "house_bills.csv"
        render "index.csv" 
      end
    end
    total_entries = @balance_events.count(:id)
    @balance_events = @balance_events.default_order.all_includes.paginate :page => params[:page], :total_entries => total_entries
  end

  def chart
    balance_entries = @account.balance_entries.accessible_by(current_ability)
    authorize! :show, BalanceEvent
    params[:query] ||= {}
    params[:query][:chart] = true
    query = BalanceEventQuery.new(params[:query],session,current_user)
    balance_entries_to_display = query.apply_conditions(balance_entries)
    @shareholders = Shareholder.find(balance_entries_to_display.uniq.pluck(:shareholder_id)).sort_by{|sh| sh.name }

    @starting_balances = balance_entries.select("shareholder_id, SUM(amount) AS amount").group("shareholder_id").where(:shareholder_id => @shareholders.map{|sh| sh.id }).where("date < ?",query.start_date)
    balances = {}
    @starting_balances.each {|sb| balances[sb.shareholder] = sb.amount }
    
    @change_entries = balance_entries_to_display.select("date, shareholder_id, SUM(amount) AS amount").group("date, shareholder_id")
    changes = {}
    @change_entries.each do |ce|
      changes[ce.shareholder] ||= {}
      changes[ce.shareholder][ce.date] = ce.amount
    end

    end_date = query.end_date || @change_entries.map{|c| c.date }.max

    this_date = query.start_date
    begin
      this_date += 1.day
    end while this_date < end_date
    
    columns = [['string','Date']]
    @shareholders.each {|sh| columns << ['number',sh.name] }

    rows = []
    this_date = query.start_date
    begin
      row = [this_date]
      @shareholders.each do |sh|
        balances[sh] += changes[sh][this_date] if changes[sh][this_date].present?
        row << balances[sh].to_f
      end
      rows << row
      this_date += 1.day
    end while this_date < end_date
    render :json => {
      :type => 'LineChart',
      :cols => columns,
      :rows => rows,
      :options => {
        :chartArea => { :width => '90%', :height => '75%' }
      }
    }
  end
end
