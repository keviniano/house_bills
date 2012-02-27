class BalanceEntriesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :balance_entry, :through => :account

  # GET /bills
  def index
    @balance_events = @balance_entries.events.paginate :page => params[:page]
  end
end
