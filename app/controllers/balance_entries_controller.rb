class BalanceEntryQuery
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_reader :start_date, :end_date, :payee_shareholder_id, :with_text, :share_shareholder_id, :bill_type_id 

  def self.grouped_shareholders
    # ['Anyone',nil] + Shareholder.order(:name).map{|sh| [sh.name, sh.id]}
    result = {'All' => [['Anyone',nil]],'Active' => [], 'Inactive' => []}
    Shareholder.order(:name).each do |sh|
      result[sh.status].push([sh.name, sh.id])
    end
    [['All',result['All']], ['Active', result['Active']], ['Inactive', result['Inactive']]]
  end

  def self.bill_types(account)
    [['All types of',nil]] + (AccountEntry.valid_entry_types.each{|item| [item,item] } + BillType.for_account(account).each.map{|row| [row.name,row.id]}).sort{|a,b| a[0] <=> b[0] }
  end

  def initialize(params,session,user)
    params ||= {}

    @with_text = params[:with_text] if params[:with_text].present?
    @start_date = Date.strptime(params[:start_date],'%m-%d-%Y') if params[:start_date].present?
    @end_date = Date.strptime(params[:end_date],'%m-%d-%Y') if params[:end_date].present?
    @share_shareholder_id = params[:share_shareholder_id].to_i if params[:share_shareholder_id].present?
    @payee_shareholder_id = params[:payee_shareholder_id].to_i if params[:payee_shareholder_id].present?
    @bill_type_id = (params[:bill_type_id] =~/^[0-9]+$/ ? params[:bill_type_id].to_i : params[:bill_type_id]) if params[:bill_type_id].present?
  end

  def persisted?
    false
  end

  def apply_conditions(balance_entries)
    balance_entries = balance_entries.with_text(with_text) if with_text
    balance_entries = balance_entries.starting_on(start_date) if start_date
    balance_entries = balance_entries.ending_on(end_date) if end_date
    balance_entries = balance_entries.with_payee_shareholder_id(payee_shareholder_id) if payee_shareholder_id 
    balance_entries = balance_entries.with_share_shareholder_id(share_shareholder_id) if share_shareholder_id 
    if bill_type_id.is_a?(Integer)
      balance_entries = balance_entries.with_bill_type_id(bill_type_id) 
    elsif bill_type_id == 'Deposit'
      balance_entries = balance_entries.deposits
    elsif bill_type_id == 'Withdrawal'
      balance_entries = balance_entries.withdrawals
    end
    balance_entries
  end
end

class BalanceEntriesController < ApplicationController
  before_filter :authenticate_user!
  load_and_authorize_resource :account
  load_and_authorize_resource :balance_entry, :through => :account

  # GET /bills
  def index
    @query = BalanceEntryQuery.new(params[:query],session,current_user)
    @balance_events = @query.apply_conditions(@balance_entries).events.paginate :page => params[:page]
    @shareholder = current_user.shareholder_for_account(@account)
  end
end
