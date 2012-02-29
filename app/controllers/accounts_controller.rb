class AccountsController < ApplicationController
  load_and_authorize_resource 
  before_filter :authenticate_user!

  # GET /accounts
  def index
    @accounts = @accounts.order(:name)
  end

  # GET /accounts/1
  def show

  end

  # GET /accounts/new
  def new
  
  end

  # GET /accounts/1/edit
  def edit
  
  end

  # POST /accounts
  def create
    m = @account.shareholders.build
    m.user = current_user
    m.name = current_user.name
    m.email = current_user.email
    m.role = Role.find_by_name("Owner")

    if @account.save
      redirect_to @account, :notice => "Account '#{@account.name}' was successfully created."
    else
      render :action => "new"
    end
  end

  # PUT /accounts/1
  def update
    if @account.update_attributes(params[:account])
      redirect_to @account, :notice => "Account '#{@account.name}' was successfully edited."
    else
      render :action => "edit"
    end
  end

  # DELETE /accounts/1
  def destroy
    @account.destroy

    redirect_to :accounts, :notice => "Account '#{@account.name}' was successfully deleted"
  end

  def edit_pot

  end

  def update_pot

  end
end
