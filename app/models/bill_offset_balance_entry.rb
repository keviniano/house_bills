class BillOffsetBalanceEntry < BalanceEntry
  belongs_to :bill
  belongs_to :account

  validates_presence_of :shareholder_id
end
