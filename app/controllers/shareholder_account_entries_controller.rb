class ShareholderAccountEntriesController < ApplicationController
  before_action :authenticate_user!
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
      render :new, status: :unprocessable_entity
    end
  end

  def edit

  end

  def update
    if @shareholder_account_entry.update(resource_params)
      redirect_to [:edit,@account,@shareholder_account_entry], :notice => 'Account entry was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shareholder_account_entry.destroy
    redirect_to account_account_entries_path(@account), notice: 'Account entry was successfully deleted.', status: :see_other
  end

  private

    def resource_params
      params.require(:shareholder_account_entry).permit(
        :entry_type,
        :date,
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
