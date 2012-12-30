class ChartQuery
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_reader :start_date, :end_date

  def initialize(params,session,user)
    params ||= {}
    @current_user = user
    @account_id = session[:account_id]
    if params[:start_date].present?
      @start_date = Date.strptime(params[:start_date],'%m-%d-%Y') 
    else
      @start_date = Date.today - 3.months
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

  def balance_line_chart
    balance_entries = @account.balance_entries.accessible_by(current_ability)
    authorize! :show, BalanceEvent
    params[:query] ||= {}
    params[:query][:chart] = true
    query = ChartQuery.new(params[:query],session,current_user)
    balance_entries_to_display = query.apply_conditions(balance_entries)
    @shareholders = Shareholder.find(balance_entries_to_display.uniq.pluck(:shareholder_id)).sort_by{|sh| sh.name }

    @starting_balances = balance_entries.select("shareholder_id, SUM(amount) AS amount").group("shareholder_id").where(:shareholder_id => @shareholders.map{|sh| sh.id }).where("date < ?",query.start_date)
    balances = {}
    @starting_balances.each {|sb| balances[sb.shareholder] = sb.amount }
    @shareholders.each {|sh| balances[sh] ||= 0 }
    
    @change_entries = balance_entries_to_display.select("date, shareholder_id, SUM(amount) AS amount").group("date, shareholder_id")
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
    render :json => {
      :type => 'LineChart',
      :cols => columns,
      :rows => rows,
      :options => {
        :chartArea => { :width => '90%', :height => '90%' },
        :legend => { :position => :in }
      }
    }
  end
end
