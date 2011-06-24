class ShareholderAccountEntry < AccountEntry
  before_validation  :update_account_offset

  validates_presence_of :shareholder_id

  private

  def update_account_offset
    build_account_offset_balance_entry if account_offset_balance_entry.blank? 
    %w{ shareholder_id account_id amount }.each {|attr| account_offset_balance_entry[attr] = self[attr] }
  end
end
