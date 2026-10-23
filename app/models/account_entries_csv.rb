# The account ledger export, newest first, between ending and starting balance rows.
class AccountEntriesCsv
  include ActiveSupport::NumberHelper

  def initialize(account_entries)
    @account_entries = account_entries.to_a
  end

  def to_csv
    CSV.generate do |csv|
      csv << [ "Date", "Check", "Payee", "Amount", "Cleared Amount", "Note" ]
      next if @account_entries.empty?

      first = @account_entries.first
      csv << [ nil, nil, "Ending Balance", number_to_currency(first.this_balance),
               number_to_currency(first.cleared_balance), nil ]

      @account_entries.each do |entry|
        csv << [ entry.date, entry.check_number, entry.recipient, number_to_currency(entry.amount),
                 (number_to_currency(entry.amount) if entry.cleared), entry.note ]
      end

      last = @account_entries.last
      csv << [ nil, nil, "Starting Balance", number_to_currency(last.prior_balance),
               number_to_currency(last.prior_cleared_balance), nil ]
    end
  end
end
