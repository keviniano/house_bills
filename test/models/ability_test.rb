require "test_helper"

# Who can do what: owner / admin / user / inactive / closed / outsider, own vs. others'
# entries, and records before the lock date.
class AbilityTest < ActiveSupport::TestCase
  setup do
    create_household
    @owner_role = @role
    @admin_role = Role.find_or_create_by!(name: "Administrator")
    @user_role  = Role.find_or_create_by!(name: "User")

    @owner = member(@ann, @owner_role)
    @admin = member(@bob, @admin_role)
    @user  = member(@cat, @user_role)
    @outsider = User.create!(name: "Out", email: "out@example.com")
  end

  def member(shareholder, role)
    user = User.create!(name: shareholder.name, email: "#{shareholder.name.downcase}@example.com")
    shareholder.update!(user: user, role: role)
    user
  end

  def ability(user) = Ability.new(user)

  def bill_by(user, **attrs)
    create_bill(shareholder: @ann, **attrs).tap { |bill| bill.update_columns(creator_id: user.id) }
  end

  def entry_by(user)
    ShareholderAccountEntry.create!(account: @account, shareholder: @cat, date: Date.new(2024, 3, 20),
                                    entry_type: "Deposit", entry_amount: "10.00").tap { |e| e.update_columns(creator_id: user.id) }
  end

  test "the account itself: owners can delete it, admins can edit it, users can only read it" do
    assert ability(@owner).can?(:destroy, @account)
    assert ability(@admin).can?(:update, @account)
    assert ability(@admin).cannot?(:destroy, @account)
    assert ability(@user).can?(:read, @account)
    assert ability(@user).cannot?(:update, @account)
    assert ability(@outsider).cannot?(:read, @account)
  end

  test "anyone signed in can start a new account" do
    assert ability(@outsider).can?(:create, Account)
  end

  test "bill types and payees are managed by admins and read by everyone in the account" do
    payee = Payee.create!(account: @account, name: "PG&E")
    [ @bill_type, payee ].each do |record|
      assert ability(@admin).can?(:destroy, record)
      assert ability(@user).can?(:read, record)
      assert ability(@user).cannot?(:update, record)
      assert ability(@outsider).cannot?(:read, record)
    end
  end

  test "admins manage members, but only owners manage owners" do
    assert ability(@admin).can?(:update, @cat)
    assert ability(@admin).cannot?(:update, @ann)
    assert ability(@owner).can?(:update, @ann)
    assert ability(@user).cannot?(:update, @bob)
    assert ability(@user).can?(:read, @bob)
  end

  test "users manage their own bills and entries; admins manage everyone's" do
    own_bill, others_bill = bill_by(@user), bill_by(@owner)
    own_entry, others_entry = entry_by(@user), entry_by(@owner)

    assert ability(@user).can?(:update, own_bill)
    assert ability(@user).can?(:destroy, own_entry)
    assert ability(@user).cannot?(:update, others_bill)
    assert ability(@user).cannot?(:destroy, others_entry)
    assert ability(@user).can?(:read, others_bill)

    assert ability(@admin).can?(:destroy, others_bill)
    assert ability(@admin).can?(:update, own_entry)
    assert ability(@outsider).cannot?(:read, own_bill)
  end

  test "account bills and unbound entries follow the same own-vs-admin rule" do
    account_bill = create_bill(AccountBill, payee: "PG&E").tap { |b| b.update_columns(creator_id: @owner.id) }
    unbound = UnboundAccountEntry.create!(account: @account, payee: "Bank", entry_type: "Deposit", entry_amount: "5.00")
    unbound.update_columns(creator_id: @user.id)

    assert ability(@user).cannot?(:update, account_bill)
    assert ability(@admin).can?(:update, account_bill)
    assert ability(@user).can?(:update, unbound)
  end

  test "new bills are allowed for active members when they are the creator" do
    assert ability(@user).can?(:create, ShareholderBill.new(account: @account, creator_id: @user.id))
    assert ability(@user).cannot?(:create, ShareholderBill.new(account: @account, creator_id: @owner.id))
    assert ability(@outsider).cannot?(:create, ShareholderBill.new(account: @account, creator_id: @outsider.id))
  end

  test "nobody, not even the owner, can change records before the lock date" do
    own_bill, own_entry = bill_by(@owner), entry_by(@owner)
    @account.update!(lock_records_before: Date.new(2024, 4, 1))
    own_bill.reload
    own_entry.reload

    %i[update destroy].each do |action|
      assert ability(@owner).cannot?(action, own_bill), action
      assert ability(@owner).cannot?(action, own_entry), action
    end
    assert ability(@owner).can?(:read, own_bill)
    assert ability(@user).can?(:update_cleared, own_entry), "clearing is still allowed when locked"
  end

  test "any open member can mark entries cleared, even other people's" do
    assert ability(@user).can?(:update_cleared, entry_by(@owner))
    assert ability(@outsider).cannot?(:update_cleared, entry_by(@owner))
  end

  test "inactive members can still read but no longer change anything, even their own" do
    own_bill = bill_by(@user)
    @cat.update!(inactivated_on: Date.current - 1)

    assert ability(@user).can?(:read, @account)
    assert ability(@user).can?(:read, own_bill)
    assert ability(@user).cannot?(:update, own_bill)
  end

  test "closed members lose access entirely" do
    own_bill = bill_by(@user)
    @cat.update!(closed_on: Date.current - 1)

    assert ability(@user).cannot?(:read, @account)
    assert ability(@user).cannot?(:read, own_bill)
  end

  test "membership of one account gives nothing in another" do
    other = Account.create!(name: "Elsewhere")
    Shareholder.create!(account: other, name: "Zed", role: @user_role, opened_on: Date.new(2020, 1, 1))

    assert ability(@owner).cannot?(:read, other)
    assert ability(@owner).cannot?(:read, other.bill_types.build)
  end
end
