# The account activity export: one row per bill or member account entry, with a column
# of balance changes per member, between ending and starting balance rows.
class BalanceEventsCsv
  include ActiveSupport::NumberHelper

  def initialize(balance_events, shareholders)
    @balance_events = balance_events.to_a
    @shareholders = shareholders
  end

  def to_csv
    CSV.generate do |csv|
      csv << [ "Date", "Payee", "Bill", "Credit", "Type", "Note" ] + @shareholders.map(&:name)
      next if @balance_events.empty?

      first = source(@balance_events.first)
      csv << [ nil, "Ending Balance", nil, nil, nil, nil ] +
             @shareholders.map { |sh| number_to_currency(first.balance_for(sh)) }

      @balance_events.each do |event|
        if event.bill.present?
          bill = event.bill
          csv << [ bill.date, bill.recipient, number_to_currency(bill.bill_amount),
                   number_to_currency(bill.credit_amount), bill.bill_type.name, bill.note ] +
                 @shareholders.map { |sh| number_to_currency(bill.shareholder_change_amount(sh)) }
        else
          entry = event.account_entry
          csv << [ entry.date, entry.recipient, number_to_currency(entry.withdrawal_amount),
                   number_to_currency(entry.deposit_amount), entry.entry_type, entry.note ] +
                 @shareholders.map { |sh| number_to_currency(entry.shareholder_offset_amount(sh)) }
        end
      end

      last = source(@balance_events.last)
      csv << [ nil, "Starting Balance", nil, nil, nil, nil ] +
             @shareholders.map { |sh| number_to_currency(last.prior_balance_for(sh)) }
    end
  end

  private

  def source(event)
    event.bill.presence || event.account_entry
  end
end
