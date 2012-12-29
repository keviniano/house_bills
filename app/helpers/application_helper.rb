module ApplicationHelper
  def chart_tag (params = {})
    params[:format] ||= :json
    path = chart_account_balance_events_path(params)
    content_tag(:div, :'data-chart' => path, :style => "height: #{400}px;") do
    end
  end
end
