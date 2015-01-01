class AccountOffsetBalanceEntry < BalanceEntry
  belongs_to :account
  belongs_to :account_entry
  belongs_to :balance_event
end
