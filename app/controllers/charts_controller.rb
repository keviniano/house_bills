class ChartsController < ApplicationController
  before_action :authenticate_user!
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
