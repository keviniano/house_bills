module ApplicationHelper
  def chart_tag (action, height,params = {})
    params[:format] ||= :json
    params[:action]   = action
    path = charts_path(action, params)
    content_tag(:div, :'data-chart' => path, :style => "height: #{height}px;") do
    end
  end

  def bill_description(bill)
    if bill.type == 'AccountBill'
      'Account Bill'
    else
      'Shareholder Bill'
    end
  end
end
