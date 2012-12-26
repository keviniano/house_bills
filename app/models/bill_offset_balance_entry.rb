class BillOffsetBalanceEntry < BalanceEntry
  belongs_to :bill
  belongs_to :account
  belongs_to :balance_event

  validates_presence_of :shareholder_id
end
