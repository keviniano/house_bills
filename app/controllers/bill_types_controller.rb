class BillTypesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :bill_type, through: :account

  # GET /bill_types/new
  def new

  end

  # GET /bill_types/1/edit
  def edit

  end

  # POST /bill_types
  def create
    if @bill_type.save
      redirect_to account_path(@account, anchor: "bill-types-tab"), notice: 'Bill type was successfully created.'
    else
      render :new
    end
  end

  # PATCH /bill_types/1
  def update
    if @bill_type.update_attributes(resource_params)
      redirect_to account_path(@account, anchor: "bill-types-tab"), notice: 'Bill type was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /bill_types/1
  def destroy
    @bill_type.destroy
    redirect_to account_path(@account, anchor: "bill-types-tab"), notice: 'Bill type was successfully deleted.'
  end

  private

    def resource_params
      params.require(:bill_type).permit(:name)
    end
end
