class ShareholderAccountEntriesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :shareholder_account_entry, :through => :account

  def show

  end

  def new
    @shareholder = current_user.shareholder_for_account(@account)
    @shareholder_account_entry.shareholder = @shareholder 
  end

  def create
    if @shareholder_account_entry.save
      redirect_to [:edit,@account,@shareholder_account_entry], :notice => 'Account entry was successfully created.'
    else
      render :new
    end
  end

  def edit

  end

  def update
    if @shareholder_account_entry.update_attributes(resource_params)
      redirect_to [:edit,@account,@shareholder_account_entry], :notice => 'Account entry was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    # TODO fix up redirect, flash msg
    @shareholder_account_entry.destroy
    redirect_to :action => :index, :controller => :account_entries
  end

  private

    def resource_params
      params.require(:shareholder_account_entry).permit(
        :entry_type,
        :date_string,
        :check_number,
        :shareholder_id,
        :entry_amount,
        :note,
        :cleared,
        :bill_share_balance_entries_attributes => [
          :id,
          :shareholder_id,
          :share,
          :account_id,
          :_destroy
        ]
      )
    end
end
