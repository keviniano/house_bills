class AccountBill < Bill
  before_validation :update_offset
  accepts_nested_attributes_for :bill_account_entry

  validates_associated      :bill_account_entry
  validates_presence_of     :payee
  validates_length_of       :payee, :maximum => 50

  private

  def update_offset
    build_bill_account_entry if bill_account_entry.blank?
    bill_account_entry.entry_type = (entry_type == 'Bill' ? 'Withdrawal' : 'Deposit')
    bill_account_entry.entry_amount = entry_amount
    %w{ payee date note account_id }.each {|attr| bill_account_entry[attr] = self[attr] }
  end
end
