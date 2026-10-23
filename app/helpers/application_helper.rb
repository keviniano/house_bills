module ApplicationHelper
  # A Google chart drawn by the chart Stimulus controller from the JSON at url.
  def chart_tag(url, height)
    content_tag(:div, nil, data: { controller: "chart", chart_url_value: url }, style: "height: #{height}px;")
  end

  def bill_description(bill)
    if bill.type == 'AccountBill'
      'Account Bill'
    else
      'Shareholder Bill'
    end
  end
end
