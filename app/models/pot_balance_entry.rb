class PotBalanceEntry < BalanceEntry
  belongs_to :account
  belongs_to :bill, optional: true
  belongs_to :balance_event, optional: true
end
