class AccountEntriesController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :account_entry, :through => :account

  # GET /account_entries
  def index
    @query = AccountEntryQuery.new(params[:query],session,current_user)
    @account_entries = @query.apply_conditions(@account_entries).order('account_entries.date DESC, account_entries.id DESC').includes(:bill)
    if params[:output] == 'CSV'
      send_data AccountEntriesCsv.new(@account_entries).to_csv, filename: "account_entries.csv", type: :csv
    else
      @account_entries = @account_entries.paginate :page => params[:page]
    end
  end

  def update_cleared
    cleared = params.require(:account_entries).permit!.to_h.transform_values { |attrs| attrs[:cleared] == "1" }
    @account.account_entries.accessible_by(current_ability, :update_cleared).where(id: cleared.keys).find_each do |entry|
      entry.update!(cleared: cleared[entry.id.to_s]) if entry.cleared != cleared[entry.id.to_s]
    end
    redirect_to account_account_entries_path @account
  end
end
