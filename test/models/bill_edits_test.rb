require "test_helper"

# What happens to the stored balance rows when bills and payments are edited or removed.
class BillEditsTest < ActiveSupport::TestCase
  setup { create_household }

  def nested(bill, changes)
    bill.bill_share_balance_entries.map do |entry|
      { id: entry.id, shareholder_id: entry.shareholder_id, share: entry.share.to_s }.merge(changes.fetch(entry.shareholder, {}))
    end
  end

  test "changing the amount recalculates every share, the pot and the payer's offset" do
    bill = create_bill(amount: "100.01", shareholder: @ann)
    bill.update!(entry_type: "Bill", entry_amount: "40.00")

    assert_equal [ -1_000, -1_000, -2_000 ], bill.reload.bill_share_balance_entries.order(:id).map(&:amount_cents)
    assert_equal 0, bill.pot_balance_entry.amount_cents
    assert_equal 4_000, bill.bill_offset_balance_entry.amount_cents
    assert_equal 0, @account.balance_entries.sum(:amount_cents)
  end

  test "removing someone from a bill re-splits it between the rest" do
    bill = create_bill(amount: "90.00", shareholder: @ann)
    bill.update!(entry_type: "Bill", entry_amount: "90.00",
                 bill_share_balance_entries_attributes: nested(bill, @cat => { _destroy: "1" }))

    assert_equal [ @ann, @bob ], bill.reload.bill_share_balance_entries.map(&:shareholder)
    assert_equal [ -4_500, -4_500 ], bill.bill_share_balance_entries.map(&:amount_cents)
    assert_equal BigDecimal("0"), @cat.balance
  end

  test "changing a share ratio re-splits the bill" do
    bill = create_bill(amount: "90.00", shareholder: @ann)
    bill.update!(entry_type: "Bill", entry_amount: "90.00",
                 bill_share_balance_entries_attributes: nested(bill, @cat => { share: "1" }))

    assert_equal [ -3_000, -3_000, -3_000 ], bill.reload.bill_share_balance_entries.order(:id).map(&:amount_cents)
  end

  test "a zero or blank share leaves that member off the bill" do
    bill = create_bill(amount: "10.00", shareholder: @ann, shares: { @ann => 1, @bob => 0, @cat => 1 })
    assert_equal [ @ann, @cat ], bill.bill_share_balance_entries.map(&:shareholder)
  end

  test "changing who paid moves the offset to the new payer" do
    bill = create_bill(amount: "40.00", shareholder: @ann)
    bill.update!(entry_type: "Bill", entry_amount: "40.00", shareholder: @bob)

    assert_equal @bob.id, bill.reload.bill_offset_balance_entry.shareholder_id
    assert_equal BigDecimal("-10.00"), @ann.balance
    assert_equal BigDecimal("30.00"), @bob.balance
  end

  test "moving a bill's date moves its balance rows and event with it" do
    bill = create_bill(shareholder: @ann)
    bill.update!(entry_type: "Bill", entry_amount: "100.00", date: Date.new(2024, 5, 1))

    assert_equal [ Date.new(2024, 5, 1) ], BalanceEntry.where(bill: bill).distinct.pluck(:date)
    assert_equal Date.new(2024, 5, 1), bill.balance_event.reload.date
  end

  test "deleting a bill removes every row it created" do
    bill = create_bill(AccountBill, amount: "40.00", payee: "PG&E")
    bill.destroy!

    assert_equal 0, BalanceEntry.count
    assert_equal 0, AccountEntry.count
    assert_equal 0, BalanceEvent.count
  end

  test "an account bill credit is a deposit to the account" do
    bill = create_bill(AccountBill, amount: "12.00", entry_type: "Credit", payee: "Refund")
    assert_equal "Deposit", bill.bill_account_entry.entry_type
    assert_equal 1_200, bill.bill_account_entry.amount_cents
    assert_equal BigDecimal("6.00"), @cat.balance # 2 of 4 shares
  end

  test "a member's payment into the account credits their balance and the account" do
    ShareholderAccountEntry.create!(account: @account, shareholder: @bob, entry_type: "Deposit", entry_amount: "25.00")
    assert_equal BigDecimal("25.00"), @bob.balance
    assert_equal BigDecimal("25.00"), @account.balance
  end

  test "a member's withdrawal debits them" do
    entry = ShareholderAccountEntry.create!(account: @account, shareholder: @bob, entry_type: "Withdrawal", entry_amount: "5.00")
    assert_equal(-500, entry.account_offset_balance_entry.amount_cents)
    entry.destroy!
    assert_equal BigDecimal("0"), @bob.balance
  end

  test "locked? compares the date with the account's lock date" do
    bill = create_bill(shareholder: @ann)
    entry = UnboundAccountEntry.create!(account: @account, payee: "Bank", date: Date.new(2024, 3, 15),
                                        entry_type: "Deposit", entry_amount: "1.00")
    assert_not bill.locked?
    assert_not entry.locked?

    @account.update!(lock_records_before: Date.new(2024, 3, 15))
    assert_not bill.reload.locked?, "the lock date itself is still open"
    @account.update!(lock_records_before: Date.new(2024, 3, 16))
    assert bill.reload.locked?
    assert entry.reload.locked?
  end

  test "records with no account count as locked" do
    assert ShareholderBill.new.locked?
    assert UnboundAccountEntry.new.locked?
  end
end
