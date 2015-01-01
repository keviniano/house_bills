class BillShareBalanceEntry < BalanceEntry
  belongs_to :bill
  belongs_to :account
  belongs_to :balance_event

  validates_presence_of :shareholder_id
  validates_numericality_of :share, :greater_than_or_equal_to => 0, :message => "must be a number 0 or higher"

  default_value_for :share, 1
  default_value_for :amount, 0

  class << self
    def shareholder(s)
      where(:shareholder_id == s.id).first
    end
  end
end
