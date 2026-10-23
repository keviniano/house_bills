class BillsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :bill, through: :account

  def show_shares
    render layout: false
  end
end
