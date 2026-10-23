require "application_system_test_case"

# The everyday loop in a real browser: sign in, enter a bill, see everyone's balances
# move, record a payment on the ledger, and export both lists to CSV.
class BillWorkflowTest < ApplicationSystemTestCase
  setup do
    create_household
    @ann.update!(email: "ann@example.com")
  end

  def open_account_menu_and_click(link)
    find("a.dropdown-toggle", text: @account.name).click
    click_on link
  end

  test "sign in, add a bill, check balances, record a payment and export CSV" do
    sign_in_with_google("ann@example.com", name: "Ann")
    assert_text @account.name

    visit account_balance_events_path(@account)
    open_account_menu_and_click "Enter a bill paid for by a housemate"
    choose "Bill"
    fill_in "Entry amount", with: "100.01"
    select "Utilities", from: "Bill type"
    fill_in "Note", with: "Electricity"
    all("input.share-ratio")[2].fill_in(with: "2") # Cat
    click_on "Create Shareholder bill"
    assert_text "Bill was successfully created"

    open_account_menu_and_click "View account activity"
    assert_selector "td", text: "Electricity"
    # Ann paid 100.01 and owes a quarter of it (rounded up); the 3¢ rounding goes to the pot.
    assert_equal 7_500, @ann.balance_entries.sum(:amount_cents)
    assert_equal(-5_002, @cat.balance_entries.sum(:amount_cents))
    assert_equal 3, @account.pot_balance_entries.sum(:amount_cents)

    click_on "Expand"
    within("turbo-frame[complete]") { assert_text "Cat" }

    open_account_menu_and_click "Add a ledger entry to credit a housemate"
    choose "Deposit"
    select "Cat", from: "Shareholder"
    fill_in "Entry amount", with: "50.02"
    click_on "Create Shareholder account entry"
    assert_text "successfully created"

    open_account_menu_and_click "View account ledger"
    assert_selector "td", text: "Cat"
    assert_text "$50.02"
    assert_equal 0, @cat.balance_entries.sum(:amount_cents)

    click_on "Search Options"
    click_on "Export"
    rows = CSV.read(downloaded_file("*.csv"))
    assert_equal "Ending Balance", rows.second[2]
    assert_includes rows.flatten, "$50.02"
    FileUtils.rm_rf(Dir[ApplicationSystemTestCase::DOWNLOADS.join("*")])

    visit account_balance_events_path(@account)
    click_on "Search Options"
    click_on "Export"
    rows = CSV.read(downloaded_file("*.csv"))
    assert_equal %w[Date Payee Bill Credit Type Note Ann Bob Cat], rows.first
    assert_includes rows.map { |row| row[5] }, "Electricity"
  end

  test "someone who hasn't been invited is turned away" do
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: "x", info: { email: "stranger@example.com", email_verified: true }
    )
    visit root_path
    click_on "Sign in with Google"
    assert_text "hasn't been invited"
  end
end
