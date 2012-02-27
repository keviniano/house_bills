class AccountBillsController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :account_bill, :through => :account

  # GET /account_bills/new
  def new
    @account_bill.build_bill_share_entries!
    @account_bill.build_bill_account_entry
  end

  # GET /account_bills/1/edit
  def edit

  end

  # POST /account_bills
  def create
    if @account_bill.save!
      redirect_to [:edit,@account,@account_bill], :notice => 'Bill was successfully created.'
    else
      render :new
    end
  end

  # PUT /account_bills/1
  def update
    if @account_bill.update_attributes(params[:account_bill])
      redirect_to [:edit,@account,@account_bill], :notice => 'Bill was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /account_bills/1
  def destroy
    @account_bill.destroy
    redirect_to :action => :index, :controller => :bills
  end
end
