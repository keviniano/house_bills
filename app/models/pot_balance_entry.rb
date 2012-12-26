class PotBalanceEntry < BalanceEntry
  belongs_to :bill
  belongs_to :account
  belongs_to :balance_event


end
