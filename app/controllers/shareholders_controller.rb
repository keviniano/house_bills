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
      redirect_to account_path(@account), :notice => "Shareholder '#{@shareholder.name}' was successfully created."
    else
      render :action => "new"
    end
  end

  # PUT /shareholders/1
  def update
    if @shareholder.update_attributes(params[:shareholder])
      redirect_to account_path(@account), :notice => "Shareholder '#{@shareholder.name}' was successfully edited."
    else
      render :action => "edit"
    end
  end

  # DELETE /shareholders/1
  def destroy
    @shareholder.destroy

    redirect_to :accounts, :notice => "Shareholder '#{@shareholder.name}' was successfully deleted"
  end

end
