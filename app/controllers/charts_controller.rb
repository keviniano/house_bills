class ChartQuery
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_reader :start_date, :end_date, :shareholder_id

  def self.grouped_shareholders
    result = {'All' => [['Anyone',nil]],'Active' => [], 'Inactive' => []}
    Shareholder.order(:name).each do |sh|
      result[sh.status].push([sh.name, sh.id])
    end
    [['All',result['All']], ['Active', result['Active']], ['Inactive', result['Inactive']]]
  end

  def initialize(params, session, user, account)
    params ||= {}
    if params[:start_date].present?
      @start_date = Date.strptime(params[:start_date],'%m-%d-%Y')
    else
      @start_date = Date.today.beginning_of_month - 1.year
    end

    if params[:end_date].present?
      @end_date = Date.strptime(params[:end_date],'%m-%d-%Y')
    else
      @end_date = Date.today.end_of_month
    end

    if params[:shareholder_id].present?
      @shareholder_id = params[:shareholder_id].to_i
    else
      @shareholder_id = user.shareholder_for_account(account).id
    end
  end

  def persisted?
    false
  end

  def apply_conditions(model)
    model = model.starting_on(start_date) if start_date
    model = model.ending_on(end_date) if end_date
    model
  end
end

class ChartsController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account

  def bill_types_by_month
    bills = @account.bills.accessible_by(current_ability)
    authorize! :show, Bill
    @q = ChartQuery.new(params[:q], session, current_user, @account)
    bills_to_display = @q.apply_conditions(bills).sum_of_bills_by_type_and_month_for_shareholder(@q.shareholder_id)
    @values =     Hash.new
    @months =     Hash.new(0)
    @bill_types = Hash.new(0)
    bills_to_display.each do |b|
      @values[[b.bill_type, [b['year'].to_i ,b['month'].to_i]]] = b.amount
      @months[[b['year'].to_i,b['month'].to_i]] += b.amount
      @bill_types[b.bill_type] += b.amount
    end
  end

  def balance_line_chart
    balance_entries = @account.balance_entries.accessible_by(current_ability)
    authorize! :show, BalanceEvent
    balance_entries_to_display = query.apply_conditions(balance_entries)
    @shareholders = Shareholder.find(balance_entries_to_display.uniq.pluck(:shareholder_id)).sort_by{|sh| sh.name }

    @starting_balances = balance_entries.
      select("shareholder_id, SUM(amount) AS amount").
      group("shareholder_id").
      where(shareholder_id: @shareholders.map{|sh| sh.id }).
      where("date < ?",query.start_date).
      includes(:shareholder)
    balances = {}
    @starting_balances.each {|sb| balances[sb.shareholder] = sb.amount }
    @shareholders.each {|sh| balances[sh] ||= 0 }

    @change_entries = balance_entries_to_display.
      select("date, shareholder_id, SUM(amount) AS amount").
      group("date, shareholder_id").
      includes(:shareholder)
    changes = {}
    @change_entries.each do |ce|
      changes[ce.shareholder] ||= {}
      changes[ce.shareholder][ce.date] = ce.amount
    end

    end_date = query.end_date || @change_entries.map{|c| c.date }.max

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
    render json: {
      type: 'LineChart',
      cols: columns,
      rows: rows,
      options: {
        chartArea: { width: '90%', height: '90%' },
        legend: { position: :in }
      }
    }
  end

  def bill_types_by_month_line_chart
    bills = @account.bills.accessible_by(current_ability)
    authorize! :show, BalanceEvent
    query = ChartQuery.new(params[:query],session,current_user,@account)
    bills_to_display = query.apply_conditions(bills).
      select  ('bill_type_id, extract(month from date) AS month, extract(year from date) AS year,  sum(amount) as amount').
      group   ('bill_type_id, extract(month from date), extract(year from date)').
      order   ('extract(year from date), extract(month from date)').
      includes(:bill_type)

    values = {}
    months = []
    bill_types = []
    bills_to_display.each do |b|
      values[b.bill_type.name] ||= {}
      values[b.bill_type.name][[b['year'],b['month']]] = b.amount
      months << [b['year'],b['month']] unless months.include? [b['year'],b['month']]
      bill_types << b.bill_type.name unless bill_types.include? b.bill_type.name
    end
    bill_types.sort!

    columns = [['string','Month']]
    bill_types.each {|bt| columns << ['number', bt] }

    rows = []
    months.each do |month|
      row = ["#{month[1]}-#{month[0]}"]
      bill_types.each {|bt| row << (values[bt][month].to_f || 0) }
      rows << row
    end

    render json: {
      type: 'LineChart',
      cols: columns,
      rows: rows,
      options: {
        chartArea: { width: '90%', height: '90%' },
        legend: { position: :in },
        curveType: 'function'
      }
    }
  end

  def bill_types_by_month_for_current_user_line_chart
    bills = @account.bills.accessible_by(current_ability)
    authorize! :show, Bill
    @q = ChartQuery.new(params[:q],session,current_user,@account)
    bills_to_display = @q.apply_conditions(bills).sum_of_bills_by_type_and_month_for_shareholder(@q.shareholder_id)
    values = {}
    months = []
    bill_types = []
    bills_to_display.each do |b|
      values[b.bill_type.name] ||= {}
      values[b.bill_type.name][[b['year'],b['month']]] = b.amount
      months << [b['year'],b['month']] unless months.include? [b['year'],b['month']]
      bill_types << b.bill_type.name unless bill_types.include? b.bill_type.name
    end
    bill_types.sort!
    months.sort!

    columns = [['string','Month']]
    bill_types.each {|bt| columns << ['number', bt] }

    rows = []
    months.each do |month|
      row = ["#{month[1].to_i}-#{month[0].to_i}"]
      bill_types.each {|bt| row << (values[bt][month].to_f || 0) }
      rows << row
    end

    render json: {
      type: 'LineChart',
      cols: columns,
      rows: rows,
      options: {
        chartArea: { width: '90%', height: '90%' },
        legend: { position: :in },
      }
    }
  end
end
