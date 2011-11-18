class AccountBillsController < ApplicationController
  before_filter :authenticate_user!

  # GET /account_bills/new
  def new
    @shareholder, @account = verify_account_access(current_user, params)
    @bill = @account.account_bills.new
    @bill.build_bill_share_entries!
    @bill.build_bill_account_entry
    render :new
  end

  # GET /account_bills/1/edit
  def edit
    @shareholder, @account = verify_account_access(current_user, params)
    @bill = @account.account_bills.find(params[:id])
    render :edit
  end

  # POST /account_bills
  def create
    @shareholder, @account = verify_account_access(current_user, params)
    @bill = @account.account_bills.new(params[:account_bill])
    if @bill.save!
      redirect_to [:edit,@account,@bill], :notice => 'Bill was successfully created.'
    else
      render :new
    end
  end

  # PUT /account_bills/1
  def update
    @shareholder, @account = verify_account_access(current_user, params)
    @bill = @account.account_bills.find(params[:id])
    if @bill.update_attributes(params[:account_bill])
      redirect_to [:edit,@account,@bill], :notice => 'Bill was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /account_bills/1
  def destroy
    @shareholder, @account = verify_account_access(current_user, params)
    @bill = @account.account_bills.find(params[:id])
    @bill.destroy
    redirect_to :action => :index, :controller => :bills
  end
end
