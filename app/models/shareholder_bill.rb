class ShareholderBill < Bill
  before_validation :update_offset

  validates_presence_of :shareholder_id

  private

  def update_offset
    build_bill_offset_balance_entry if bill_offset_balance_entry.blank?
    %w{ shareholder_id account_id date amount }.each {|attr| bill_offset_balance_entry[attr] = self[attr] }
  end
end
