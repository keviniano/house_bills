require "test_helper"

class ShareholderTest < ActiveSupport::TestCase
  setup do
    create_household
    @ann.update!(opened_on: Date.new(2021, 1, 1), inactivated_on: Date.new(2022, 1, 1), closed_on: Date.new(2023, 1, 1))
  end

  test "open from opened_on through closed_on, inclusive" do
    assert_not_includes @account.shareholders.open_as_of(Date.new(2020, 12, 31)), @ann
    assert_includes     @account.shareholders.open_as_of(Date.new(2021, 1, 1)), @ann
    assert_includes     @account.shareholders.open_as_of(Date.new(2023, 1, 1)), @ann
    assert_not_includes @account.shareholders.open_as_of(Date.new(2023, 1, 2)), @ann
  end

  test "active from opened_on through inactivated_on, inclusive" do
    assert_includes     @account.shareholders.active_as_of(Date.new(2022, 1, 1)), @ann
    assert_not_includes @account.shareholders.active_as_of(Date.new(2022, 1, 2)), @ann
  end

  test "members with no end dates stay open and active" do
    assert_includes @account.shareholders.open_now, @bob
    assert_includes @account.shareholders.active_now, @bob
    assert @bob.active?
  end

  test "active? is false on and after the inactivation date" do
    @bob.inactivated_on = Date.current
    assert_not @bob.active?
    assert_equal "Inactive", @bob.status
    @bob.inactivated_on = Date.current + 1
    assert @bob.active?
  end

  test "a new bill only offers the members active on its date" do
    bill = ShareholderBill.new(account: @account, date: Date.new(2022, 6, 1))
    bill.build_bill_share_entries!
    assert_equal [ @bob, @cat ], bill.bill_share_balance_entries.map(&:shareholder)
  end

  test "owners are admins; administrators are admins but not owners; users are neither" do
    assert @ann.admin?
    assert @ann.owner?
    @bob.update!(role: Role.find_or_create_by!(name: "Administrator"))
    assert @bob.admin?
    assert_not @bob.owner?
    @cat.update!(role: Role.find_or_create_by!(name: "User"))
    assert_not @cat.admin?
  end

  test "a new member is linked to an existing user by email, ignoring case" do
    user = User.create!(name: "Dee", email: "dee@example.com")
    dee = Shareholder.create!(account: @account, name: "Dee", role: @role, email: " Dee@Example.com ")
    assert_equal user, dee.user
  end

  test "names are unique within an account" do
    assert_not Shareholder.new(account: @account, name: "Ann", role: @role).valid?
    assert Shareholder.new(account: Account.create!(name: "Other"), name: "Ann", role: @role).valid?
  end
end
