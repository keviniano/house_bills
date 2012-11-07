class AccountEntryQuery
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_reader :start_date, :end_date, :payee_shareholder_id, :with_text, :entry_type, :cleared_status

  def self.grouped_shareholders
    # ['Anyone',nil] + Shareholder.order(:name).map{|sh| [sh.name, sh.id]}
    result = {'All' => [['Anyone',nil]],'Active' => [], 'Inactive' => []}
    Shareholder.order(:name).each do |sh|
      result[sh.status].push([sh.name, sh.id])
    end
    [['All',result['All']], ['Active', result['Active']], ['Inactive', result['Inactive']]]
  end

  def self.cleared_statuses
    [['Cleared and pending',nil], ['Cleared',true], ['Pending',false]]
  end

  def self.entry_types
    [['both deposits and withdrawals',nil], ['deposits only', 'Deposit'], ['withdrawals only', 'Withdrawal']] 
  end

  def initialize(params,session,user)
    params ||= {}

    @cleared_status = (params[:cleared_status] == 'true' ? true : false) if params[:cleared_status].present?
    @with_text = params[:with_text] if params[:with_text].present?
    @start_date = Date.strptime(params[:start_date],'%m-%d-%Y') if params[:start_date].present?
    @end_date = Date.strptime(params[:end_date],'%m-%d-%Y') if params[:end_date].present?
    @payee_shareholder_id = params[:payee_shareholder_id].to_i if params[:payee_shareholder_id].present?
    @entry_type = params[:entry_type] if params[:entry_type].present?
  end

  def persisted?
    false
  end

  def apply_conditions(account_entries)
    account_entries = account_entries.with_text(with_text) if with_text
    account_entries = account_entries.starting_on(start_date) if start_date
    account_entries = account_entries.ending_on(end_date) if end_date
    account_entries = account_entries.with_payee_shareholder_id(payee_shareholder_id) if payee_shareholder_id 
    if entry_type == 'Deposit'
      account_entries = account_entries.deposits
    elsif entry_type == 'Withdrawal'
      account_entries = account_entries.withdrawals
    end
    if cleared_status == true
      account_entries = account_entries.cleared
    elsif cleared_status == false
      account_entries = account_entries.pending
    end
    account_entries
  end
end

class AccountEntriesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :account_entry, :through => :account

  # GET /account_entries
  def index
    @query = AccountEntryQuery.new(params[:query],session,current_user)
    @account_entries = @query.apply_conditions(@account_entries).order('account_entries.date DESC, account_entries.id DESC').includes(:bill).paginate :page => params[:page]
  end
end
