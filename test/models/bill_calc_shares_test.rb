require "test_helper"

class BillCalcSharesTest < ActiveSupport::TestCase
  # Bill.calc_shares as it was in 2011-2017, mixing Float and BigDecimal. Kept here
  # verbatim so the integer-cents version can be checked against it.
  def legacy_calc_shares(share_ratios, bill_amount)
    gcd = nil
    total_shares = share_ratios.inject {|sum, n| sum + n }
    share_ratios.each do |s|
      gcd = (gcd ||= s).gcd(s) unless s <= 0
    end
    if total_shares == 0
      base_portion = 0
    else
      if (bill_amount * 100) % (total_shares / gcd) == 0
        base_portion = bill_amount / (total_shares / gcd)
        remainder = 0
      else
        base_portion = (((bill_amount.to_f / (total_shares / gcd) * 100).floor.to_f / 100) + 0.01)
        remainder = -((bill_amount - ((total_shares / gcd) * base_portion)) * 100).round.to_f / 100
      end
    end
    [base_portion, gcd, remainder]
  end

  # What Bill#update_balance_entries stored for each share and the pot, in cents,
  # after the old decimal(10,2) column rounded the values.
  def legacy_split(share_ratios, cents)
    base, gcd, remainder = legacy_calc_shares(share_ratios, BigDecimal(cents) / 100)
    shares = share_ratios.map { |share| share == 0 ? 0 : MoneyColumn.to_cents((-share / gcd) * base) }
    [shares, MoneyColumn.to_cents(remainder)]
  end

  def split(share_ratios, cents)
    base_cents, gcd, remainder_cents = Bill.calc_shares(share_ratios, cents)
    shares = share_ratios.map { |share| share == 0 ? 0 : -(share / gcd) * base_cents }
    [shares, remainder_cents]
  end

  test "matches the legacy Float version on a grid of share ratios and amounts" do
    ratio_sets = [ [1], [1, 1], [1, 1, 1], [1, 2], [2, 2, 2], [1, 0, 1], [3, 1, 1, 1],
                   [1, 1, 1, 1, 1, 1, 1], [2, 3], [4, 6, 8], [5, 0, 0, 2], [1, 1, 2, 2, 3] ]
    amounts = (-1_500..1_500).to_a + [ 99_999, 123_457, 1_000_001, -33_334, 999_999_99 ]

    ratio_sets.each do |ratios|
      amounts.each do |cents|
        assert_equal legacy_split(ratios, cents), split(ratios, cents), "ratios #{ratios.inspect}, #{cents} cents"
      end
    end
  end

  test "matches the legacy Float version on random bills" do
    random = Random.new(2011)
    2_000.times do
      ratios = Array.new(random.rand(1..8)) { random.rand(0..6) }
      ratios[0] = random.rand(1..6)
      cents = random.rand(-2_000_000..2_000_000)
      assert_equal legacy_split(ratios, cents), split(ratios, cents), "ratios #{ratios.inspect}, #{cents} cents"
    end
  end

  test "rounds each share up to the cent and puts the difference in the pot" do
    assert_equal [ 334, 1, 2 ], Bill.calc_shares([ 1, 1, 1 ], 1_000)
    assert_equal [ [ -334, -334, -334 ], 2 ], split([ 1, 1, 1 ], 1_000)
  end

  test "rounds credits towards zero, so the pot takes the difference the other way" do
    assert_equal [ [ 333, 333, 333 ], 1 ], split([ 1, 1, 1 ], -1_000)
  end

  test "splits evenly divisible bills exactly" do
    assert_equal [ [ -500, -1_000 ], 0 ], split([ 1, 2 ], 1_500)
    assert_equal [ [ -500, -1_000 ], 0 ], split([ 2, 4 ], 1_500)
  end

  test "gives zero shares nothing" do
    assert_equal [ [ -500, 0, -500 ], 0 ], split([ 1, 0, 1 ], 1_000)
  end

  test "has no remainder when there are no positive shares, like the legacy version" do
    assert_equal [ 0, nil, nil ], Bill.calc_shares([ 0, 0 ], 1_000)
    assert_nil legacy_calc_shares([ 0, 0 ], BigDecimal("10"))[2]
  end
end
