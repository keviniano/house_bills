class ShareholderBillsController < ApplicationController
  before_filter :authenticate_user!

  # GET /shareholder_bills/new
  def new
    @shareholder, @account = verify_account_access(current_user, params)
    @bill = @account.shareholder_bills.build :shareholder => @shareholder
    @bill.build_bill_share_entries!
    render :new
  end

  # GET /shareholder_bills/1/edit
  def edit
    @shareholder, @account = verify_account_access(current_user, params)
    @bill = @account.shareholder_bills.find(params[:id])
    render :edit
  end

  # POST /shareholder_bills
  def create
    @shareholder, @account = verify_account_access(current_user, params)
    @bill = @account.shareholder_bills.new(params[:shareholder_bill])
    if @bill.save
      redirect_to [:edit,@account,@bill], :notice => 'Bill was successfully created.'
    else
      render :new
    end
  end

  # PUT /shareholder_bills/1
  def update
    @shareholder, @account = verify_account_access(current_user, params)
    @bill = @account.shareholder_bills.find(params[:id])
    if @bill.update_attributes(params[:shareholder_bill])
      redirect_to [:edit,@account,@bill], :notice => 'Bill was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /shareholder_bills/1
  def destroy
    @shareholder, @account = verify_account_access(current_user, params)
    @bill = @account.bills.find(params[:id])
    @bill.destroy
    redirect_to :action => :index, :controller => :bills
  end
end
