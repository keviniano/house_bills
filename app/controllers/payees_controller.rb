class PayeesController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :payee, through: :account

  # GET /payees/new
  def new

  end

  # GET /payees/1/edit
  def edit

  end

  # POST /payees
  def create
    if @payee.save
      redirect_to account_path(@account, anchor: "payees-tab"), notice: 'Payee was successfully created.'
    else
      render :new
    end
  end

  # PATCH /payees/1
  def update
    if @payee.update_attributes(resource_params)
      redirect_to account_path(@account, anchor: "payees-tab"), notice: 'Payee was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /payees/1
  def destroy
    @payee.destroy
    redirect_to account_path(@account, anchor: "payees-tab"), notice: 'Payee was successfully deleted.'
  end

  private

    def resource_params
      params.require(:payee).permit(:name)
    end
end
