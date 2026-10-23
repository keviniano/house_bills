class BillShareBalanceEntry < BalanceEntry
  after_update :touch_parent_bill

  validates_presence_of :shareholder_id
  validates_numericality_of :share, :greater_than_or_equal_to => 0, :message => "must be a number 0 or higher"

  attribute :share, default: 1

  class << self
    def shareholder(s)
      find_by(shareholder_id: s.id)
    end
  end

  private

  def touch_parent_bill
    bill.touch
  end
end
