class UnboundAccountEntriesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :unbound_account_entry, :through => :account

  def show

  end

  def new
    prep_edit
  end

  def create
    if @unbound_account_entry.save
      redirect_to [:edit,@account,@unbound_account_entry], :notice => 'Account entry was successfully created.'
    else
      prep_edit
      render :new
    end
  end

  def edit
    prep_edit
  end

  def update
    if @unbound_account_entry.update_attributes(resource_params)
      redirect_to [:edit,@account,@unbound_account_entry], :notice => 'Account entry was successfully updated.'
    else
      prep_edit
      render :edit
    end
  end

  def destroy
    @unbound_account_entry.destroy
    redirect_to account_account_entries_path(@account), notice: 'Account entry was successfully deleted.'
  end

  private

    def prep_edit
      @payees = @account.payees
    end

    def resource_params
      params.require(:unbound_account_entry).permit(
        :entry_type,
        :date_string,
        :check_number,
        :payee,
        :entry_amount,
        :bill_type_id,
        :note,
        :cleared
      )
    end
end

