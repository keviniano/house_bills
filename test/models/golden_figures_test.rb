require "test_helper"

class GoldenFiguresTest < ActiveSupport::TestCase
  setup do
    create_household
    create_bill(amount: "100.01", shareholder: @ann)
    create_bill(AccountBill, amount: "40.00", payee: "PG&E")
    ShareholderAccountEntry.create!(account: @account, shareholder: @bob, entry_type: "Deposit", entry_amount: "25.00", cleared: true)
  end

  test "computes the same figures the recording script does, in cents" do
    figures = GoldenFigures.current
    assert_equal 2, figures["counts"]["bills"]
    assert_equal({ "balance_cents" => -1_500, "cleared_balance_cents" => 2_500, "pot_cents" => 3,
                   "balance_entries_cents" => -1_500, "bills_cents" => 14_001 }, figures["accounts"][@account.id.to_s])
    assert_equal 10_001 - 2_501 - 1_000, figures["shareholders"][@ann.id.to_s]
    assert_equal(-2_501 - 1_000 + 2_500, figures["shareholders"][@bob.id.to_s])
  end

  test "members with no balance rows count as zero" do
    dee = Shareholder.create!(account: @account, name: "Dee", role: @role)
    assert_equal 0, GoldenFigures.current["shareholders"][dee.id.to_s]
  end

  test "reports nothing when the figures match and every difference when they don't" do
    expected = GoldenFigures.current
    assert_empty GoldenFigures.differences(expected)

    expected = expected.deep_dup
    expected["accounts"][@account.id.to_s]["pot_cents"] = 4
    expected["shareholders"].delete(@cat.id.to_s)
    assert_equal [ "accounts.#{@account.id}.pot_cents: expected 4, got 3",
                   "shareholders.#{@cat.id}: not in the recorded figures" ], GoldenFigures.differences(expected)
  end

  test "the recorded file is optional" do
    assert_nil GoldenFigures.recorded(Rails.root.join("tmp/no-such-figures.json"))
  end
end
