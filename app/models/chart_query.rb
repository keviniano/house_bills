class ChartQuery
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_reader :start_date, :end_date, :shareholder_id

  def self.grouped_shareholders(account)
    result = {'All' => [['Anyone',nil]],'Active' => [], 'Inactive' => []}
    account.shareholders.order(:name).each do |sh|
      result[sh.status].push([sh.name, sh.id])
    end
    [['All',result['All']], ['Active', result['Active']], ['Inactive', result['Inactive']]]
  end

  def initialize(params, session, user, account)
    params ||= {}
    if params[:start_date].present?
      @start_date = parse_date(params[:start_date])
    else
      @start_date = Date.current.beginning_of_month - 1.year
    end

    if params[:end_date].present?
      @end_date = parse_date(params[:end_date])
    else
      @end_date = Date.current.end_of_month
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

  # Search forms send yyyy-mm-dd from <input type="date">; ignore anything else.
  def parse_date(value)
    Date.iso8601(value)
  rescue Date::Error, TypeError
    nil
  end

  def apply_conditions(model)
    model = model.starting_on(start_date) if start_date
    model = model.ending_on(end_date) if end_date
    model
  end
end
