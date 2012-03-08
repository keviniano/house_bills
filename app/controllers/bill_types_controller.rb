class BillTypesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :bill_type, :through => :account

  # GET /bill_types/new
  def new

  end

  # GET /bill_types/1/edit
  def edit

  end

  # POST /bill_types
  def create
    if @bill_type.save
      redirect_to @account, :notice => 'Bill type was successfully created.'
    else
      render :new
    end
  end

  # PUT /bill_types/1
  def update
    if @bill_type.update_attributes(params[:bill_type])
      redirect_to @account, :notice => 'Bill type was successfully updated.'
    else
      render :new
    end
  end

  # DELETE /bill_types/1
  def destroy
    @bill_type.destroy

    redirect_to @account, :notice => 'Bill type was successfully deleted.'
  end
end
