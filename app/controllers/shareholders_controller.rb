class ShareholdersController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :shareholder, through: :account

  # GET /shareholders/new
  def new

  end

  # GET /shareholders/1/edit
  def edit

  end

  # POST /shareholders
  def create
    if @shareholder.save
      redirect_to account_path(@account, anchor: "shareholders-tab"), notice: "Shareholder '#{@shareholder.name}' was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH /shareholders/1
  def update
    if @shareholder.update(update_resource_params)
      redirect_to account_path(@account, anchor: "shareholders-tab"), notice: "Shareholder '#{@shareholder.name}' was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /shareholders/1
  def destroy
    if @shareholder.destroy
      redirect_to account_path(@account, anchor: "shareholders-tab"), notice: "Shareholder '#{@shareholder.name}' was successfully deleted.", status: :see_other
    else
      redirect_to account_path(@account, anchor: "shareholders-tab"), alert: "Shareholder '#{@shareholder.name}' has entries, so they can't be deleted. Set a closed date instead.", status: :see_other
    end
  end

  private

    def resource_params
      allowed_params = [:role_id, :name, :email]
      params.require(:shareholder).permit(allowed_params)
    end

    def update_resource_params
      allowed_params = [
        :role_id, 
        :opened_on, 
        :inactivated_on, 
        :closed_on
      ]
      allowed_params.concat([:name, :email]) if @shareholder.user.blank?
      params.require(:shareholder).permit(allowed_params)
    end
end
