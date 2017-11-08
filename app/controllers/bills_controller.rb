class BillsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :bill, through: :account

  def show_shares
    respond_to do |format|
      format.html { render partial: "bills/shares", content_type: "text/html", locals: { bill: @bill } }
    end
  end
end
