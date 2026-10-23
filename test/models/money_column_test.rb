require "test_helper"

class MoneyColumnTest < ActiveSupport::TestCase
  class Entry < ApplicationRecord
    self.table_name = "balance_entries"
    include MoneyColumn
    money_attribute :amount
  end

  test "reads cents as an exact BigDecimal" do
    entry = Entry.new(amount_cents: 12_345)
    assert_instance_of BigDecimal, entry.amount
    assert_equal BigDecimal("123.45"), entry.amount
  end

  test "reads nil cents as nil" do
    assert_nil Entry.new(amount_cents: nil).amount
  end

  test "writes strings, integers, BigDecimals and floats as cents" do
    {
      "123.45" => 12_345,
      "-0.07" => -7,
      " 10 " => 1_000,
      42 => 4_200,
      BigDecimal("19.99") => 1_999,
      0.1 + 0.2 => 30,
      33.33 => 3_333
    }.each do |input, cents|
      assert_equal cents, Entry.new(amount: input).amount_cents, "for #{input.inspect}"
    end
  end

  test "rounds half away from zero to the cent, like the old decimal(10,2) column" do
    assert_equal 1_235, Entry.new(amount: "12.345").amount_cents
    assert_equal(-1_235, Entry.new(amount: "-12.345").amount_cents)
    assert_equal 1_234, Entry.new(amount: "12.3449").amount_cents
  end

  test "writes blank as nil so presence validations still fire" do
    assert_nil Entry.new(amount: "").amount_cents
    assert_nil Entry.new(amount: nil).amount_cents
  end

  test "round-trips through the database" do
    entry = Entry.create!(amount: "-1234.56")
    assert_equal(-123_456, entry.reload.amount_cents)
    assert_equal BigDecimal("-1234.56"), entry.amount
  end
end
