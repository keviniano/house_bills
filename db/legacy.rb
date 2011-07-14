require 'csv'
require 'legacy_helper'
require 'pp'

a = Account.find_or_create_by_name "Imported Account"
role = Role.find_by_name "User"
unknown_bill_type = a.bill_types.find_or_create_by_name('Unknown')

emails = {}
File.open(File.join(Rails.root,'db','legacy','email.txt')).each_line do |line|
  this_line = line.split(",")
  emails[this_line[0]] = this_line[1].strip!
end

CSV.foreach(File.join(Rails.root,'db','legacy','lkpPayee.txt'),headers: true) do |r|
  if r["Initials"].blank?
    p = a.payees.find_or_initialize_by_id(r["PayeeID"])
    p.name = r["Payee"]
    p.save!
  else
    s = a.shareholders.find_or_initialize_by_id(r["PayeeID"])
    s.role = role
    s.name = r["Payee"]
    s.email = emails[s.name] if emails.key?(s.name)
    s.opened_on = Date.today
    s.save!
  end
end

ActiveRecord::Base.connection.execute("SELECT setval('payees_id_seq',#{Payee.maximum(:id)})")
ActiveRecord::Base.connection.execute("SELECT setval('shareholders_id_seq',#{Shareholder.maximum(:id)})")

CSV.foreach(File.join(Rails.root,'db','legacy','tblBillExpense.txt'),headers: true) do |r|
  if r['Payee'].present?
    if r['LedgerID'].present?
      bill = a.account_bills.find_or_initialize_by_id(r['ExpenseID'])
      bill.payee = r['Payee']
    elsif r['BillPmtID'].present?
      bill = a.shareholder_bills.find_or_initialize_by_id(r['ExpenseID'])
      bill.shareholder = Shareholder.find_by_name(r['Payee']) 
    else
      raise 'What??'
    end
    bill.date = fix_up_date(r['ReceivedDate'])
    bill.entry_amount = fix_up_currency(r['ExpenseAmount']).abs
    bill.entry_type = (fix_up_currency(r['ExpenseAmount']) > 0 ? 'Bill' : 'Credit')
    bill.note = r['Description']
    bill.bill_type = a.bill_types.find_or_create_by_name(r['BillType']) unless r['BillType'].blank?
    bill.bill_type = unknown_bill_type if bill.bill_type.blank?
    bill.save!
  end
end
ActiveRecord::Base.connection.execute("SELECT setval('bills_id_seq',#{Bill.maximum(:id)})")

AccountEntry.destroy_all
CSV.foreach(File.join(Rails.root,'db','legacy','tblAccountLedger.txt'),headers: true) do |r|
  if r['ExpenseID'].present?
    ae = a.bill_account_entries.find_or_initialize_by_id(r['LedgerID'])
    ae.payee = r['Payee']
    ae.bill_id = r['ExpenseID']
  elsif r['BillPmtID'].present?
    ae = a.shareholder_account_entries.find_or_initialize_by_id(r['LedgerID'])
    ae.shareholder = Shareholder.find_by_name(r['Payee']) 
    raise "No shareholder matching name #{r['Payee']} on Ledger ID #{r['LedgerID']}" if ae.shareholder.blank? 
  else
    ae = a.unbound_account_entries.find_or_initialize_by_id(r['LedgerID'])
    ae.payee = r['Payee']
  end
  ae.check_number = r['CheckNumber']
  ae.date = fix_up_date(r['EntryDate'])
  ae.cleared = r['Cleared']
  ae.note = r['Description']
  if r['Credit'].present?
    ae.entry_amount = fix_up_currency(r['Credit'])
    ae.entry_type = 'Deposit'
    ae.save! 
  elsif r['Debit'].present?
    ae.entry_amount = fix_up_currency(r['Debit'])
    ae.entry_type = 'Withdrawal'
    ae.save!
  end
end
ActiveRecord::Base.connection.execute("SELECT setval('account_entries_id_seq',#{AccountEntry.maximum(:id)})")

BalanceEntry.destroy_all
CSV.foreach(File.join(Rails.root,'db','legacy','tblBillPayment.txt'),headers: true) do |r|
  if r['Amount'].present?
    if r['LedgerID'].present?
      be = a.account_offset_balance_entries.find_or_initialize_by_id(r['BillPmtID'])
      ae = AccountEntry.find(r['LedgerID'])
      be.account_entry = ae
      be.date = ae.date
    elsif r['ExpenseID'].present?
      if r['IsShare'].to_i == 1
        be = a.bill_share_balance_entries.find_or_initialize_by_id(r['BillPmtID'])
        be.share = r['Share']
      else
        be = a.bill_offset_balance_entries.find_or_initialize_by_id(r['BillPmtID'])
      end
      bill = Bill.find(r['ExpenseID'])
      be.bill = bill
      be.date = bill.date
    end
    be.shareholder_id = r['PersonID']
    be.amount = fix_up_currency(r['Amount'])
    be.save!
  end
end
ActiveRecord::Base.connection.execute("SELECT setval('balance_entries_id_seq',#{BalanceEntry.maximum(:id)})")

PotBalanceEntry.destroy_all
AccountBill.all.each do |sb|
  share_total = sb.bill_share_balance_entries.sum(:amount)
  p = sb.build_pot_balance_entry if sb.pot_balance_entry.blank?
  p.account = a
  p.date = sb.date
  p.amount = -(sb.amount + share_total)
  p.save!
end

ShareholderBill.all.each do |sb|
  share_total = sb.bill_share_balance_entries.sum(:amount)
  p = sb.build_pot_balance_entry if sb.pot_balance_entry.blank?
  p.account = a
  p.date = sb.date
  p.amount = -(sb.amount + share_total)
  p.save!
end
