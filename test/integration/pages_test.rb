require "test_helper"

# Every page and workflow, as a signed-in owner, through the full stack.
class PagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    create_household
    @user = User.create!(name: "Ann", email: "ann@example.com")
    @ann.update!(user: @user, email: @user.email)
    @payee = Payee.create!(account: @account, name: "PG&E")
    @bill = create_bill(amount: "100.01", shareholder: @ann)
    @account_bill = create_bill(AccountBill, amount: "40.00", payee: "PG&E")
    @payment = ShareholderAccountEntry.create!(account: @account, shareholder: @bob, date: Date.new(2024, 3, 20),
                                               entry_type: "Deposit", entry_amount: "25.01")
    @unbound = UnboundAccountEntry.create!(account: @account, payee: "Bank", date: Date.new(2024, 3, 21),
                                           entry_type: "Deposit", entry_amount: "5.00")
    sign_in @user
  end

  test "accounts index and overview" do
    get accounts_path
    assert_response :success
    assert_select "h2", text: @account.name

    get account_path(@account)
    assert_response :success
    assert_select "#shareholders", text: /Cat/
    assert_select "a[data-turbo-method=delete]", text: "Delete Account For Ever and Ever"
  end

  test "account activity, with search, totals and running balance" do
    get account_balance_events_path(@account, q: { start_date: "2024-01-01" })
    assert_response :success
    assert_select "td", text: "PG&E"
    assert_select "turbo-frame[loading=lazy][src='#{show_shares_account_bill_path(@account, @bill)}']"

    get account_balance_events_path(@account, q: { start_date: "2024-03-01", end_date: "2024-03-31",
                                                   with_text: "PG", bill_type_id: @bill_type.id })
    assert_response :success
    assert_select "input[type=date][value='2024-03-01']"
  end

  test "expanding a bill loads its shares in a frame" do
    get show_shares_account_bill_path(@account, @bill)
    assert_response :success
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(@bill, :shares)}", text: /Cat/
  end

  test "account activity CSV export" do
    get account_balance_events_path(@account, output: "CSV", q: { start_date: "2024-01-01" })
    assert_response :success
    assert_equal "text/csv", response.media_type
    rows = CSV.parse(response.body)
    assert_equal [ "Date", "Payee", "Bill", "Credit", "Type", "Note", "Ann", "Bob", "Cat" ], rows.first
    assert_equal "Ending Balance", rows.second[1]
    assert_equal "Starting Balance", rows.last[1]
    assert_includes rows.map(&:second), "PG&E"
  end

  test "account activity CSV export refuses more than 250 events and shows the page instead" do
    BalanceEvent.insert_all(Array.new(251) { { account_id: @account.id, account_entry_id: @unbound.id, date: Date.new(2024, 3, 1) } })

    get account_balance_events_path(@account, output: "CSV", q: { start_date: "2024-01-01" })
    assert_response :success
    assert_equal "text/html", response.media_type
    assert_match "cannot be for more than 250", response.body
  end

  test "ledger, its CSV export and updating cleared flags" do
    get account_account_entries_path(@account)
    assert_response :success
    assert_select "td", text: "Bank"

    get account_account_entries_path(@account, output: "CSV")
    assert_equal "text/csv", response.media_type
    assert_equal "Ending Balance", CSV.parse(response.body).second[2]

    post update_cleared_account_account_entries_path(@account),
         params: { account_entries: { @unbound.id => { cleared: "1" }, @payment.id => { cleared: "0" } } }
    assert_redirected_to account_account_entries_path(@account)
    assert @unbound.reload.cleared
    assert_not @payment.reload.cleared
  end

  test "updating cleared flags only touches this account's entries, and only the flag" do
    other = Account.create!(name: "Elsewhere")
    foreign = UnboundAccountEntry.create!(account: other, payee: "X", entry_type: "Deposit", entry_amount: "1.00")

    post update_cleared_account_account_entries_path(@account),
         params: { account_entries: { foreign.id => { cleared: "1" }, @unbound.id => { cleared: "1", amount_cents: "1" } } }
    assert_not foreign.reload.cleared
    assert_equal 500, @unbound.reload.amount_cents
  end

  test "entering a member's bill" do
    get new_account_shareholder_bill_path(@account)
    assert_response :success
    assert_select "input[type=date][name='shareholder_bill[date]']"

    assert_difference -> { ShareholderBill.count } do
      post account_shareholder_bills_path(@account), params: { shareholder_bill: {
        entry_type: "Bill", date: "2024-04-01", shareholder_id: @bob.id, entry_amount: "30.00",
        bill_type_id: @bill_type.id, note: "Groceries",
        bill_share_balance_entries_attributes: [ @ann, @bob, @cat ].each_with_index.to_h { |sh, i|
          [ i.to_s, { shareholder_id: sh.id, share: "1", account_id: @account.id } ] }
      } }
    end
    bill = ShareholderBill.last
    assert_redirected_to account_shareholder_bill_path(@account, bill)
    assert_equal @user.id, bill.creator_id
    follow_redirect!
    assert_response :success
  end

  test "a bill that fails validation re-renders with 422 so Turbo shows the errors" do
    post account_shareholder_bills_path(@account), params: { shareholder_bill: {
      entry_type: "Bill", date: "", shareholder_id: @bob.id, entry_amount: "30.00", bill_type_id: @bill_type.id } }
    assert_response :unprocessable_entity
  end

  test "entering an account bill offers the payees as suggestions" do
    get new_account_account_bill_path(@account)
    assert_response :success
    assert_select "input[name='account_bill[payee]'][list=payees]"
    assert_select "datalist#payees option[value='PG&E']"
  end

  test "editing and deleting bills" do
    get edit_account_shareholder_bill_path(@account, @bill)
    assert_response :success
    assert_select "form[data-turbo-confirm] button", text: "Delete Bill"

    get edit_account_account_bill_path(@account, @account_bill)
    assert_response :success

    patch account_shareholder_bill_path(@account, @bill), params: { shareholder_bill: { entry_amount: "90.00", entry_type: "Bill" } }
    assert_redirected_to account_shareholder_bill_path(@account, @bill)
    assert_equal 9_000, @bill.reload.amount_cents

    delete account_account_bill_path(@account, @account_bill)
    assert_response :see_other
    assert_not Bill.exists?(@account_bill.id)
  end

  test "bills before the lock date can't be edited or deleted, and new ones can't be dated before it" do
    @account.update!(lock_records_before: Date.new(2024, 4, 1))

    get account_shareholder_bill_path(@account, @bill)
    assert_response :success
    assert_select "a", text: /Edit This/, count: 0
    assert_raises(CanCan::AccessDenied) { get edit_account_shareholder_bill_path(@account, @bill) }
    assert_raises(CanCan::AccessDenied) { delete account_shareholder_bill_path(@account, @bill) }

    get new_account_shareholder_bill_path(@account)
    assert_select "input[type=date][min='2024-04-01']"
  end

  test "bill and account entry detail pages" do
    [ account_shareholder_bill_path(@account, @bill), account_account_bill_path(@account, @account_bill),
      account_shareholder_account_entry_path(@account, @payment), account_unbound_account_entry_path(@account, @unbound),
      new_account_shareholder_account_entry_path(@account), new_account_unbound_account_entry_path(@account),
      edit_account_shareholder_account_entry_path(@account, @payment), edit_account_unbound_account_entry_path(@account, @unbound) ].each do |path|
      get path
      assert_response :success, path
    end
  end

  test "member account entries and unbound entries" do
    post account_unbound_account_entries_path(@account), params: { unbound_account_entry: {
      entry_type: "Withdrawal", date: "2024-04-02", payee: "Hardware store", entry_amount: "12.34" } }
    entry = UnboundAccountEntry.last
    assert_redirected_to edit_account_unbound_account_entry_path(@account, entry)
    assert_equal(-1_234, entry.amount_cents)

    delete account_shareholder_account_entry_path(@account, @payment)
    assert_redirected_to account_account_entries_path(@account)
    assert_response :see_other
  end

  test "bill types by month chart and its JSON" do
    get account_bill_types_by_month_chart_path(@account, q: { start_date: "2024-01-01", end_date: "2024-12-31" })
    assert_response :success
    assert_select "[data-controller=chart][data-chart-url-value*='bill_types_by_month_for_current_user_line_chart.json']"

    get account_bill_types_by_month_line_chart_path(@account, format: :json, q: { start_date: "2024-01-01", end_date: "2024-12-31" })
    assert_response :success
    assert_equal "LineChart", response.parsed_body["type"]
    assert_equal [ "3-2024", 35.01 ], response.parsed_body["rows"].first # 25.01 + 10.00 shares
  end

  test "managing members, bill types and payees" do
    get new_account_shareholder_path(@account)
    assert_response :success
    get edit_account_shareholder_path(@account, @cat)
    assert_response :success
    assert_select "input[type=date][name='shareholder[opened_on]'][value='2020-01-01']"

    patch account_shareholder_path(@account, @cat), params: { shareholder: { closed_on: "2025-01-01" } }
    assert_equal Date.new(2025, 1, 1), @cat.reload.closed_on

    delete account_shareholder_path(@account, @bob)
    assert_match "can't be deleted", flash[:alert]

    get new_account_bill_type_path(@account)
    assert_response :success
    post account_bill_types_path(@account), params: { bill_type: { name: "Internet" } }
    delete account_bill_type_path(@account, @bill_type)
    assert_match "can't be deleted", flash[:alert]

    get edit_account_payee_path(@account, @payee)
    assert_response :success
    delete account_payee_path(@account, @payee)
    assert_not Payee.exists?(@payee.id)
  end

  test "editing the account's lock date" do
    get edit_account_path(@account)
    assert_response :success
    patch account_path(@account), params: { account: { lock_records_before: "2024-01-01" } }
    assert_equal Date.new(2024, 1, 1), @account.reload.lock_records_before
  end

  test "creating and deleting an account" do
    post accounts_path, params: { account: { name: "Cabin" } }
    cabin = Account.find_by!(name: "Cabin")
    assert cabin.shareholders.sole.owner?

    delete account_path(cabin)
    assert_redirected_to accounts_path
    assert_not Account.exists?(cabin.id)
  end

  test "a member who isn't an owner can't delete the account" do
    @ann.update!(role: Role.find_or_create_by!(name: "User"))

    assert_raises(CanCan::AccessDenied) { delete account_path(@account) }
    assert Account.exists?(@account.id)
  end
end
