class AccountBillsController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :account_bill, through: :account

  # GET /account_bills/1
  def show

  end

  # GET /account_bills/new
  def new
    @account_bill.build_bill_share_entries!
    @account_bill.build_bill_account_entry
    prep_edit
  end

  # GET /account_bills/1/edit
  def edit
    prep_edit
  end

  # POST /account_bills
  def create
    if @account_bill.save
      redirect_to [@account,@account_bill], notice: 'Bill was successfully created.'
    else
      prep_edit
      render :new
    end
  end

  # PATCH /account_bills/1
  def update
    if @account_bill.update_attributes(resource_params)
      redirect_to [@account,@account_bill], notice: 'Bill was successfully updated.'
    else
      prep_edit
      render :edit
    end
  end

  # DELETE /account_bills/1
  def destroy
    @account_bill.destroy
    redirect_to account_balance_events_path(@account), notice: 'Bill was successfully deleted.'
  end

  private

    def prep_edit
      @payees = @account.payees
    end

    def resource_params
      params.require(:account_bill).permit(
        :entry_type,
        :date_string,
        :payee,
        :entry_amount,
        :bill_type_id,
        :note,
        :bill_account_entry_attributes => [
          :check_number,
          :cleared
        ],
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
