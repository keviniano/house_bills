class ApplicationController < ActionController::Base
  protect_from_forgery
  before_action :set_current_user
  before_action :set_paper_trail_whodunnit

  protected

  def set_current_user
    Current.user = current_user
  end
end
