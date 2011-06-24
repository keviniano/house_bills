class AccountsController < ApplicationController
  before_filter :authenticate_user!

  # GET /accounts
  def index
    @accounts = Account.all 
  end

  # GET /accounts/new
  def new
    @account = Account.new
  end

  # GET /accounts/1/edit
  def edit
    @account = Account.find(params[:id])
  end

  # POST /accounts
  def create
    @account = Account.new(params[:account])

    m = @account.shareholders.build
    m.user = current_user
    m.name = current_user.name
    m.email = current_user.email
    m.role = Role.find_by_name("Owner")

    if @account.save
      redirect_to :accounts, :notice => "Account '#{@account.name}' was successfully created."
    else
      render :action => "new"
    end
  end

  # PUT /accounts/1
  def update
    @account = Account.find(params[:id])

    old_name = @account.name
    if @account.update_attributes(params[:account])
      redirect_to :edit_account, :notice => "Account '#{@account.name}' was successfully edited."
    else
      render :action => "edit"
    end
  end

  def edit_pot

  end

  def update_pot

  end

  # DELETE /accounts/1
  def destroy
    @account = Account.find(params[:id])
    @account.destroy

    redirect_to :accounts, :notice => "Account '#{@account.name}' was successfully deleted"
  end
end
