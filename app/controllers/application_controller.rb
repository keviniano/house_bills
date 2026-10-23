class ApplicationController < ActionController::Base
  protect_from_forgery
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_current_user
  before_action :set_paper_trail_whodunnit

  def  verify_account_access(user,p)
    shareholder = Shareholder.find_by user_id: user.id, account_id: p[:account_id]
    raise ActiveRecord::RecordNotFound if shareholder.nil?
    [shareholder, shareholder.account]
  end

  protected

  def set_current_user
    Current.user = current_user
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
  end
end
