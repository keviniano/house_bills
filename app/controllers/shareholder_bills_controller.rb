class ShareholderBillsController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :shareholder_bill, :through => :account

  # GET /shareholder_bills/1
  def show

  end

  # GET /shareholder_bills/new
  def new
    @shareholder = current_user.shareholder_for_account(@account)
    @shareholder_bill.shareholder = @shareholder 
    @shareholder_bill.build_bill_share_entries! 
  end

  # GET /shareholder_bills/1/edit
  def edit

  end

  # POST /shareholder_bills
  def create
    if @shareholder_bill.save
      redirect_to [:edit,@account,@shareholder_bill], :notice => 'Bill was successfully created.'
    else
      render :new
    end
  end

  # PATCH /shareholder_bills/1
  def update
    if @shareholder_bill.update_attributes(resource_params)
      redirect_to [:edit,@account,@shareholder_bill], :notice => 'Bill was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /shareholder_bills/1
  def destroy
    @shareholder_bill.destroy
    redirect_to account_balance_events_path(@account), notice: 'Bill was successfully deleted.'
  end

  private

    def resource_params
      params.require(:shareholder_bill).permit(
        :entry_type,
        :date_string,
        :shareholder_id,
        :entry_amount,
        :bill_type_id,
        :note,
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
