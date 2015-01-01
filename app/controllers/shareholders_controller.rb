class ShareholdersController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :shareholder, :through => :account

  # GET /shareholders/new
  def new
  
  end

  # GET /shareholders/1/edit
  def edit
  
  end

  # POST /shareholders
  def create
    if @shareholder.save
      redirect_to edit_account_shareholder_path(@account, @shareholder), :notice => "Shareholder '#{@shareholder.name}' was successfully created."
    else
      render :action => "new"
    end
  end

  # PATCH /shareholders/1
  def update
    if @shareholder.update_attributes(update_resource_params)
      redirect_to edit_account_shareholder_path(@account, @shareholder), :notice => "Shareholder '#{@shareholder.name}' was successfully edited."
    else
      render :action => "edit"
    end
  end

  # DELETE /shareholders/1
  def destroy
    @shareholder.destroy

    redirect_to :accounts, :notice => "Shareholder '#{@shareholder.name}' was successfully deleted"
  end

  private

    def resource_params
      allowed_params = [:role_id, :name, :email]
      params.require(:shareholder).permit(allowed_params)
    end

    def update_resource_params
      allowed_params = [:role_id, :opened_on, :inactivated_on, :closed_on]
      allowed_params.concat([:name, :email]) if @shareholder.user.blank?
      params.require(:shareholder).permit(allowed_params)
    end
end
