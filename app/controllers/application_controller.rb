class ApplicationController < ActionController::Base
  protect_from_forgery
  include Userstamp

  def  verify_account_access(user,p)
    shareholder = Shareholder.find_by user_id: user.id, account_id: p[:account_id]
    raise ActiveRecord::RecordNotFound if shareholder.nil?
    [shareholder, shareholder.account]
  end
end
