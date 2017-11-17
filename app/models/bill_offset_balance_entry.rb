class BillOffsetBalanceEntry < BalanceEntry
  belongs_to :account
  belongs_to :bill
  belongs_to :balance_event, optional: true

  validates_presence_of :shareholder_id
end
