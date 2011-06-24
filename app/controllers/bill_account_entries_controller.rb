class BillAccountEntriesController < ApplicationController
  def show
  end

  def edit
    @shareholder = Shareholder.find_by_user_id_and_account_id(current_user.id,params[:account_id])
    if @shareholder.nil?
      flash[:error] = "Account not found"
      redirect_to :action => :index
    else
      @account = @shareholder.account
      @account_entry = @account.account_entries.find(params[:id])
      @bill = @account_entry.bill
      redirect_to [:edit,@account,@bill]
    end
  end
end
