class UnboundAccountEntriesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :unbound_account_entry, :through => :account

  def new

  end

  def create
    if @unbound_account_entry.save
      redirect_to [:edit,@account,@unbound_account_entry], :notice => 'Account entry was successfully created.'
    else
      render :new
    end
  end

  def edit

  end

  def update
    if @unbound_account_entry.update_attributes(params[:unbound_account_entry])
      redirect_to [:edit,@account,@unbound_account_entry], :notice => 'Account entry was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    # TODO fix up redirect, flash msg
    @unbound_account_entry.destroy
    redirect_to :action => :index, :controller => :account_entries
  end
end

