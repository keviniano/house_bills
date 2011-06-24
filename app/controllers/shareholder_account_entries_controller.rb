class ShareholderAccountEntriesController < ApplicationController
  def new
    @shareholder, @account = verify_account_access(current_user, params)
    @account_entry = @account.shareholder_account_entries.new :shareholder => @shareholder
    render :new 
  end

  def create
    @shareholder, @account = verify_account_access(current_user, params)
    @account_entry = @account.shareholder_account_entries.new(params[:shareholder_account_entry])
    if @account_entry.save
      redirect_to [:edit,@account,@account_entry], :notice => 'Account entry was successfully created.'
    else
      render :new
    end
  end

  def edit
    @shareholder, @account = verify_account_access(current_user, params)
    @account_entry = @account.shareholder_account_entries.find(params[:id])
    render :edit
  end

  def update
    @account_entry = @account.shareholder_account_entries.find(params[:id])
    if @account_entry.update_attributes(params[:shareholder_account_entry])
      redirect_to [:edit,@account,@account_entry], :notice => 'Account entry was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @shareholder, @account = verify_account_access(current_user, params)
    @account_entry = @account.shareholder_account_entries.find(params[:id])
    @account_entry.destroy
    redirect_to :action => :index, :controller => :account_entries
  end
end
