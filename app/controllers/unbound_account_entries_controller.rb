class UnboundAccountEntriesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :unbound_account_entry, :through => :account

  def new
    @payees = @account.payees

  end

  def create
    if @unbound_account_entry.save
      redirect_to [:edit,@account,@unbound_account_entry], :notice => 'Account entry was successfully created.'
    else
      @payees = @account.payees
      render :new
    end
  end

  def edit
    @payees = @account.payees

  end

  def update
    if @unbound_account_entry.update_attributes(params[:unbound_account_entry])
      redirect_to [:edit,@account,@unbound_account_entry], :notice => 'Account entry was successfully updated.'
    else
      @payees = @account.payees
      render :edit
    end
  end

  def destroy
    # TODO fix up redirect, flash msg
    @unbound_account_entry.destroy
    redirect_to :action => :index, :controller => :account_entries
  end
end

