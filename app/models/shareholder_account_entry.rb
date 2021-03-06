class ShareholderAccountEntry < AccountEntry
  before_validation  :update_account_offset, :update_balance_event

  validates_presence_of :shareholder_id

  private

  def update_account_offset
    build_account_offset_balance_entry if account_offset_balance_entry.blank?
    %w{ shareholder_id account_id date amount }.each {|attr| account_offset_balance_entry[attr] = self[attr] }
  end

  def update_balance_event
    build_balance_event if balance_event.blank?
    balance_event.account = account
    balance_event.date = date
  end
end
