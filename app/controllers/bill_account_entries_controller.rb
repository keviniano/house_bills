class BillAccountEntriesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :bill_account_entry, :through => :account

  def show

  end

  def edit
      @bill = @bill_account_entry.bill
      redirect_to [:edit,@account,@bill]
    end
  end
end
