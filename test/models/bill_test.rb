require "test_helper"

class BillTest < ActiveSupport::TestCase
  setup { create_household }

  test "a member's bill charges each share, credits the payer and puts rounding in the pot" do
    bill = create_bill(amount: "100.01", shareholder: @ann)

    shares = bill.bill_share_balance_entries.index_by(&:shareholder)
    assert_equal(-2_501, shares[@ann].amount_cents)
    assert_equal(-2_501, shares[@bob].amount_cents)
    assert_equal(-5_002, shares[@cat].amount_cents)
    assert_equal 3, bill.pot_balance_entry.amount_cents
    assert_equal 10_001, bill.bill_offset_balance_entry.amount_cents
    assert_equal @ann.id, bill.bill_offset_balance_entry.shareholder_id

    assert_equal BigDecimal("75.00"), @ann.balance
    assert_equal BigDecimal("-25.01"), @bob.balance
    assert_equal BigDecimal("0.03"), @account.pot_balance
  end

  test "a credit reverses the signs" do
    bill = create_bill(amount: "10.00", entry_type: "Credit", shareholder: @ann, shares: { @ann => 1, @bob => 1, @cat => 1 })

    assert_equal(-1_000, bill.amount_cents)
    assert_equal [ 333, 333, 333 ], bill.bill_share_balance_entries.map(&:amount_cents)
    assert_equal 1, bill.pot_balance_entry.amount_cents
  end

  test "an account bill writes a matching withdrawal to the account register" do
    bill = create_bill(AccountBill, amount: "40.00", payee: "PG&E")

    entry = bill.bill_account_entry
    assert_equal(-4_000, entry.amount_cents)
    assert_equal "PG&E", entry.payee
    assert_equal bill.date, entry.date
    assert_equal BigDecimal("-40.00"), @account.balance
  end

  test "every bill gets a balance event on its date" do
    bill = create_bill(shareholder: @ann)
    assert_equal bill.date, bill.balance_event.date
    assert_equal @account.id, bill.balance_event.account_id
  end

  test "records the signed-in user as creator and updater" do
    user = users(:one)
    Current.set(user: user) do
      bill = create_bill(shareholder: @ann)
      assert_equal user.id, bill.creator_id
      assert_equal user.id, bill.updater_id
      assert_equal user.id, bill.bill_share_balance_entries.first.creator_id
    end
  end

  test "keeps an existing creator when someone else edits" do
    bill = create_bill(shareholder: @ann)
    bill.update_columns(creator_id: users(:one).id)

    Current.set(user: users(:two)) { bill.update!(note: "edited", entry_amount: "100.00") }
    assert_equal users(:one).id, bill.reload.creator_id
    assert_equal users(:two).id, bill.updater_id
  end

  test "a member with history can't be deleted" do
    create_bill(shareholder: @ann)

    assert_not @bob.destroy
    assert @bob.errors.any?
    assert Shareholder.exists?(@bob.id)
  end

  test "lists only this account's members in the pickers" do
    other = Account.create!(name: "Elsewhere")
    Shareholder.create!(account: other, name: "Zed", role: @role)

    names = BalanceEventQuery.grouped_shareholders(@account).flat_map { |_, members| members.map(&:first) }
    assert_equal %w[Ann Bob Cat], names
  end
end
