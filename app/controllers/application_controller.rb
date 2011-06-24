class ApplicationController < ActionController::Base
  protect_from_forgery

  def  verify_account_access(user,p)
    shareholder = Shareholder.find_by_user_id_and_account_id(user.id,p[:account_id])
    raise ActiveRecord::RecordNotFound if shareholder.nil?
    [shareholder, shareholder.account]
  end
end
