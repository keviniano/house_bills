class PayeesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :payee, :through => :account

  # GET /payees/new
  def new

  end

  # GET /payees/1/edit
  def edit

  end

  # POST /payees
  def create
    if @payee.save
      redirect_to @account, :notice => 'Payee was successfully created.'
    else
      render :new
    end
  end

  # PUT /payees/1
  def update
    if @payee.update_attributes(params[:payee])
      redirect_to @account, :notice => 'Payee was successfully updated.'
    else
      render :new
    end
  end

  # DELETE /payees/1
  def destroy
    @payee.destroy

    redirect_to @account, :notice => 'Payee was successfully deleted.'
  end
end
